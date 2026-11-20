# 2. Into Go

The first real app in this book is written in Go. Before opening it, you can
get a head start: lux will translate the game from chapter 1 into Go for you.
Reading that translation is the easiest first look at Go there is, because you
already know what every line of it does. You wrote it.

This chapter reads it. The point isn't to learn Go line by line. It's to see
how much of Go you can already read, and to pick up a few rules for the parts
that look new.

## 2.1 The translation

From the folder with `vier.lux` in it:

```text
lux convert go vier.lux > vier.go
go mod init vier
go run .
```

The first line writes the Go version of the game into `vier.go`. The second sets
the folder up as a Go project, which Go calls a *module* and needs before it
will build anything. The third builds the program and runs it, and it's the same
game:

```text
 . . . . . . .
 . . . . . . .
 . . . . . . .
 . . . . . . .
 . . . . . . .
 . . . . . . .
 1 2 3 4 5 6 7
Red, pick a column (1-7):
4
```

Open `vier.go` and look through it. It's about three hundred lines, a hundred
more than the lux. Most of it will look familiar, and some of it won't. Start
with the familiar part.

## 2.2 The same program

Here is `landingRow` in lux:

```lux
func landingRow(board: Board, column: int) -> int {
    var row = 0
    while at(board, column, row) != none {
        row += 1
    }
    return row
}
```

and in Go:

```go
func landingRow(board Board, column int) int {
	row := 0
	for at(copyBoard(board), column, row) != nil {
		row += 1
	}
	return row
}
```

It's the same function. It has the same name, takes the same two things, starts
at row 0, and counts up while the cell is taken. The differences are spelling.
Go writes the type after the name with no colon, `column int` rather than
`column: int`, and puts the type a function returns after the parentheses with
no arrow. `row := 0` makes a new variable, like `var row = 0`. Go has no
`while`: it uses `for` for every loop, and a `for` with only a condition is a
`while`. And Go's word for lux's `none` is `nil`.

Ignore `copyBoard` for now; section 2.4 comes back to it.

Most of the program reads this way. Here is `opponent`:

```go
func opponent(player Player) Player {
	switch player.(type) {
	case PlayerRed:
		return (PlayerYellow{})
	case PlayerYellow:
		return (PlayerRed{})
	}
	panic("unreachable")
}
```

`switch` is Go's `match`, and each `case` is an arm. Red becomes yellow and
yellow becomes red, as in chapter 1. The `.(type)` and the braces after
`PlayerYellow` are how this translation spells a lux enum, which section 2.3
covers, but you don't need them to see what the function does.

The last line is new. A lux `match` that leaves out a case doesn't run. A Go
`switch` that leaves one out is allowed, and the program carries on past it, so
the converter adds a line that stops the program if that ever happens. `panic`
is Go's way of stopping a program with an error. You'll see it after every
`match` the converter translates.

And the main loop:

```go
func main() {
	allLines := winningLines()
	board := emptyBoard()
	var turn Player = (PlayerRed{})
	done := false
	for !done {
		show(board)
		choice := chosenColumn(copyBoard(board), turn)
		if choice == nil {
			done = true
		} else {
			...
```

A lux program starts at its first line that isn't a declaration. A Go program
starts at a function called `main`, so the converter moves your top-level lines
into one. Inside, it's chapter 1's loop: the same three variables, the same
`show`, the same question asked of the same player.

You don't need to know Go to follow this. You need to know what the program
does and then find it in the code, and you already know what this program does.

## 2.3 What Go builds differently

Two of lux's ideas aren't part of Go, so the converter builds them out of other
parts of the language. You'll meet both in Go programs, so it helps to know what
they look like.

The first is the enum. Go has no type that is "one of these cases", the way
`Player` is red or yellow. The converter makes one type for each case and a
shared name that covers them all. Go calls that shared name an *interface*: a
group of types that all have something in common, which here is the empty
`isPlayer` each case is given.

```go
type Player interface{ isPlayer() }

type PlayerRed struct{}

func (PlayerRed) isPlayer() {}

type PlayerYellow struct{}

func (PlayerYellow) isPlayer() {}
```

You don't need to know how this works to read it. When you see a group like
this, read it as:

```lux
enum Player {
    red
    yellow
}
```

and read `PlayerRed{}` as `Player.red`. The `switch player.(type)` in
`opponent` is a *type switch*: it asks which type in the group a value is, and
that's how this translation spells a `match` on an enum. Chapter 3 shows a
simpler way Go programmers usually write a list of cases like this one.

The second is `Option`. Go doesn't have it. Instead, some Go values can be
`nil`, meaning "nothing here", and the converter uses that where lux used
`none`. So an empty cell on the board is `nil`, and `mark` checks for it:

```go
func mark(cell Player) string {
	if playerOpt := cell; playerOpt != nil {
		...
	} else {
		return "."
	}
}
```

Read `if x != nil` as the `some` arm and the `else` as the `none` arm. What you
lose is the reminder. In lux, the type `Option<Player>` told you a cell might be
empty. Here the type says only `Player`, nothing tells you to check, and a Go
programmer has to remember.

For an `Option<int>`, the converter writes `*int`, with a star. That's a
*pointer* to an `int`. A pointer doesn't hold a value itself; it leads to one
that's kept somewhere else, and chapter 3 shows what Go programmers usually
want that for. The converter wants something simpler: a pointer can be `nil`,
leading nowhere. So in converted code, read `*int` as "an `int` that might be
missing", with `nil` as the missing case. When the converter needs to make one,
it calls `ptr(column)`, short for pointer, which you can read as
`some(column)`.

## 2.4 What lux brought with it

The top of `vier.go` holds functions that aren't in your lux program at all:
`luxCheck`, `luxIndex`, `luxEqual`, `copySlice`, `copyBoard`, `readLine` and
`parseInt`. These are lux itself, written in Go. lux makes you some promises,
and when your program leaves lux, the converter brings code along to keep them.

`luxIndex` keeps the promise about indexes. Go stops a program on a bad index
too, but with a shorter message, so the converter sends every index through
`luxIndex` to keep lux's explanation. That's why `at` became:

```go
func at(board Board, column int, row int) Player {
	return luxIndex(luxIndex(board.cells, row), column)
}
```

Read `luxIndex(xs, i)` as `xs[i]`, and this is `board.cells[row][column]`.

`copyBoard` keeps the promise from chapter 1. In lux, passing a board to a
function hands over a copy, so nothing the function does can change your board.
Go copies some kinds of values and shares others, and a board built the way lux
builds one is a kind Go would share. So the converter copies the board itself,
every time it's passed anywhere, to be sure. Read `copyBoard(board)` as `board`.

The rest work the same way. `readLine` and `parseInt` are the lux functions you
called, built from Go's own, and `luxEqual` is lux's `==`. When you read
converted code, skip these and read the program underneath.

## 2.5 Reading Go you didn't write

The translation has shown you most of what you need to read Go, and very little
of it was a new idea. Most of it was new spelling for ideas you already had.
Here are this chapter's rules in one place:

| In Go | Read it as |
|---|---|
| `name type`, as in `column int` | `name: type` |
| `func f(x int) int` | `func f(x: int) -> int` |
| `x := 5` | `var x = 5` |
| `for condition { … }` | `while condition { … }` |
| `for { … }` | `while true { … }` |
| `switch … { case …: }` | `match` and its arms |
| `nil` | `none` |
| `if x != nil { … } else { … }` | the `some` and `none` arms |
| `*int`, a pointer, in converted code | `Option<int>` |
| `switch x.(type)`, a type switch | `match` on an enum |
| `func main() { … }` | the lines at the top level of a lux file |
| `panic("…")` | the program stopping with an error |

A longer list of lux and Go side by side is Appendix B of
[Programming in Go](/go/appendix-b-from-lux.html), when you want it.

The translation is lux's program in Go's spelling. It does everything the way
lux does it, and it brings lux's helpers along to make sure. A Go programmer
writing the same game would make different choices, because Go has its own ways
of saying the same things. Chapter 3 opens a Go program written that way,
vier-cli, and finds chapter 1's game inside it.
