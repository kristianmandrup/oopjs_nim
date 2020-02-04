import macros, jsffi
from strutils import join

when not defined(js):
  {.error: "oopjs.nim is only available for the JS target".}

proc argsList(vars: varags[auto]): auto =
    result = vars.join(",")

template super(vars: varags[auto]): auto =
  {.emit("super(" & argsList(vars) & ");").}

template superMethod(methodName: cstring, vars: varags[auto]): auto =
  {.emit("super." & methodName & "(" & argsList(vars) & ");").}

template constructor(vars: varags[auto], body: untyped): auto =
  {.emit("constructor(" & argsList(vars) & ")" & " {").}
  body
  {.emit("}").}

macro class*(head, body: untyped): untyped =
  # The macro is immediate, since all its parameters are untyped.
  # This means, it doesn't resolve identifiers passed to it.

  var typeName, baseName: NimNode

  # flag if object should be exported
  var isExported: bool

  if head.kind == nnkInfix and eqIdent(head[0], "of"):
    # `head` is expression `typeName of baseClass`
    # echo head.treeRepr
    # --------------------
    # Infix
    #   Ident !"of"
    #   Ident !"Animal"
    #   Ident !"RootObj"
    typeName = head[1]
    baseName = head[2]

  elif head.kind == nnkInfix and eqIdent(head[0], "*") and
       head[2].kind == nnkPrefix and eqIdent(head[2][0], "of"):
    # `head` is expression `typeName* of baseClass`
    # echo head.treeRepr
    # --------------------
    # Infix
    #   Ident !"*"
    #   Ident !"Animal"
    #   Prefix
    #     Ident !"of"
    #     Ident !"RootObj"
    typeName = head[1]
    baseName = head[2][1]
    isExported = true

  else:
    error "Invalid node: " & head.lispRepr

  # The following prints out the AST structure:
  #
  # import macros
  # dumptree:
  #   type X = ref object of Y
  #     z: int
  # --------------------
  # StmtList
  #   TypeSection
  #     TypeDef
  #       Ident !"X"
  #       Empty
  #       RefTy
  #         ObjectTy
  #           Empty
  #           OfInherit
  #             Ident !"Y"
  #           RecList
  #             IdentDefs
  #               Ident !"z"
  #               Ident !"int"
  #               Empty

  # create a new stmtList for the result
  result = newStmtList()

  # create a type section in the result
  template typeDecl(a, b): untyped =
    type a = ref object of b

  template typeDeclPub(a, b): untyped =
    type a* = ref object of b

  if isExported:
    result.add getAst(typeDeclPub(typeName, baseName))
  else:
    result.add getAst(typeDecl(typeName, baseName))

  # echo treeRepr(body)
  # --------------------
  # StmtList
  #   VarSection
  #     IdentDefs
  #       Ident !"name"
  #       Ident !"string"
  #       Empty
  #     IdentDefs
  #       Ident !"age"
  #       Ident !"int"
  #       Empty
  #   MethodDef
  #     Ident !"vocalize"
  #     Empty
  #     Empty
  #     FormalParams
  #       Ident !"string"
  #     Empty
  #     Empty
  #     StmtList
  #       StrLit ...
  #   MethodDef
  #     Ident !"age_human_yrs"
  #     Empty
  #     Empty
  #     FormalParams
  #       Ident !"int"
  #     Empty
  #     Empty
  #     StmtList
  #       DotExpr
  #         Ident !"self"
  #         Ident !"age"

  # var declarations will be turned into object fields
  var recList = newNimNode(nnkRecList)

  # expected name of constructor
  let ctorName = newIdentNode("new" & $typeName)

  # Iterate over the statements, adding `self: T`
  # to the parameters of functions, unless the
  # function is a constructor
  for node in body.children:
    case node.kind:

    of nnkMethodDef, nnkProcDef:
      # check if it is the ctor proc
      if node.name.kind != nnkAccQuoted and node.name.basename == ctorName:
        # specify the return type of the ctor proc
        node.params[0] = typeName
      else:
        # inject `self: T` into the arguments
        node.params.insert(1, newIdentDefs(ident("self"), typeName))
      result.add(node)

    of nnkVarSection:
      # variables get turned into fields of the type.
      for n in node.children:
        recList.add(n)

    else:
      result.add(node)

  # Inspect the tree structure:
  #
  # echo result.treeRepr
  # --------------------
  # StmtList
  #   TypeSection
  #     TypeDef
  #       Ident !"Animal"
  #       Empty
  #       RefTy
  #         ObjectTy
  #           Empty
  #           OfInherit
  #             Ident !"RootObj"
  #           Empty   <= We want to replace this
  #   MethodDef
  # ...

  result[0][0][2][0][2] = recList

  # Lets inspect the human-readable version of the output
  # echo repr(result)
  # Output:
  #  type
  #    Animal = ref object of RootObj
  #      name: string
  #      age: int
  #
  #  method vocalize(self: Animal): string {.base.} =
  #    "..."
  #
  #  method age_human_yrs(self: Animal): int {.base.} =
  #    self.age
  # ...
  #
  # type
  #   Rabbit = ref object of Animal
  #
  # proc newRabbit(name: string; age: int): Rabbit =
  #   result = Rabbit(name: name, age: age)
  #
  # method vocalize(self: Rabbit): string =
  #   "meep"

# ---

