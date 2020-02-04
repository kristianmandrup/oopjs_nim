# Nim OOP macros for Javascript

From [Nim by example](https://nim-by-example.github.io/macros/)

## Usage

```nim
class Animal of JsObject:
  var name: string
  var age: int
  method vocalize: string {.base.} = "..." # use `base` pragma to annotate base methods
  method age_human_yrs: int {.base.} = self.age # `self` is injected
  proc `$`: string = "animal:" & self.name & ":" & $self.age

class Dog of Animal:
  method vocalize: string = "woof"
  method age_human_yrs: int = self.age * 7
  proc `$`: string = "dog:" & self.name & ":" & $self.age

class Cat of Animal:
  method vocalize: string = "meow"
  proc `$`: string = "cat:" & self.name & ":" & $self.age

class Rabbit of Animal:
  proc newRabbit(name: string, age: int) = # the constructor doesn't need a return type
    result = Rabbit(name: name, age: age)
  method vocalize: string = "meep"
  proc `$`: string = "rabbit:" & self.name & ":" & $self.age

# ---

var animals: seq[Animal] = @[]
animals.add(Dog(name: "Sparky", age: 10))
animals.add(Cat(name: "Mitten", age: 10))

for a in animals:
  echo a.vocalize()
  echo a.age_human_yrs()

let r = newRabbit("Fluffy", 3)
echo r.vocalize()
echo r.age_human_yrs()
```

Using `super`

```nim
class Cat of Animal:
  method vocalize: string =
    superMethod('vocalize')

  method walk(yards: cint): string =
    superMethod('walk', yards)

class Rabbit of Animal:
  proc newRabbit(name: string, age: int) = # the constructor doesn't need a return type
    result = Rabbit(name: name, age: age)
  method vocalize: string = "meep"
  proc `$`: string = "rabbit:" & self.name & ":" & $self.age


class Tiger of Animal:
  constructor(name: cstring):
    super(name)

  # the constructor doesn't need a return type
  proc newTiger(name: string, age: int) =
    result = Tiger(name: name, age: age)

  method eat(food: Animal): string =
    superMethod('eat', food)
```
