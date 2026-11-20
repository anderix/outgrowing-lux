# 2. Into Go

The lux game from chapter 1 is about to become a Go program. There are two ways
to get there. One is to let lux do it: `lux convert go` writes a Go program that
plays the same game. The other is to start an empty Go project and write the
game again. This chapter does both, in that order, because reading the
translation is the fastest way to see what changes when a program moves from lux
to Go, and the reasons for starting again are in what you find there.

By the end of the chapter there is a new Go program that does very little: it
shows an empty board and waits for you to type `quit`. Everything else in the
book is built on it.

## 2.1 The translation

From the folder with `vier.lux` in it:

```text
lux convert go vier.lux > vier.go
go mod init vier
go run .
```

`lux convert` prints the Go program, and the `>` saves it to a file. `go mod
init` makes the folder a Go module, which is how Go knows which files belong to
one program and which version of Go they were written for. `go run .` compiles
the program in the current folder and runs it. It plays the same game:

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

It is also correct Go. `go vet`, which looks for code that compiles but is
probably wrong, finds nothing to complain about, and `gofmt`, the formatter
every Go programmer runs, would leave it as it is. The translation is about three
hundred lines, a hundred more than the lux. The extra hundred are where to look.

## 2.2 What lux brought with it

The top of `vier.go` is a set of small functions that aren't in `vier.lux` at
all. They are lux, written in Go: the promises lux made you, kept by code the
converter adds.

The first is the index check:

```go
func luxCheck(i, n int) int {
	if i < 0 || i >= n {
		fmt.Fprintf(os.Stderr, "error: index %d is out of bounds for an array of length %d\n", i, n)
		...
		os.Exit(1)
	}
	return i
}
```

Go checks indexes too, and a bad one stops a Go program just as it stops a lux
one. What Go doesn't do is explain itself the way lux does, so the converter
routes every index through `luxCheck` to keep lux's error message. That's why
`at`, one line in lux, is this in Go:

```go
func at(board Board, column int, row int) Player {
	return luxIndex(luxIndex(board.cells, row), column)
}
```

The second is the copy. In lux, `var next = board` gives you a separate board,
and so does passing a board to a function. Go's version of a lux array is a
*slice*, and a slice doesn't work that way. A slice is a small value that points
at the elements, which live somewhere else; copying the slice copies the pointer
and not the elements. Two slices made that way share their elements, so a
function that changes one changes the other. lux promised you that couldn't
happen, so the converter keeps the promise by copying the board each time it is
passed anywhere:

```go
func copyBoard(x Board) Board {
	return Board{
		cells: copySlice(x.cells, func(__e []Player) []Player { return append([]Player{}, __e...) }),
	}
}
```

and then, all through the program:

```go
func canDrop(board Board, column int) bool {
	if column < 0 || column >= columns() {
		return false
	}
	return at(copyBoard(board), column, rows()-1) == nil
}
```

`at` only reads the board, so this copy is never needed, but the converter can't
see that from one line. It copies everywhere a copy might matter, which means it
copies all the time. The program runs fine anyway; a board is forty-two cells.

## 2.3 What Go doesn't have

The other differences come from things lux has and Go doesn't.

Go has no enums of lux's kind, where a value is one case out of a fixed list. The
converter builds one from an *interface*, a type that names behavior any other
type can have, and one empty struct per case:

```go
type Player interface{ isPlayer() }

type PlayerRed struct{}

func (PlayerRed) isPlayer() {}

type PlayerYellow struct{}

func (PlayerYellow) isPlayer() {}
```

Anything with an `isPlayer` method is a `Player`, and only these two types have
one, so a `Player` is red or yellow. A `match` becomes a `switch` on which type
the value holds:

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

The `panic("unreachable")` at the end is there because of what Go doesn't
check. A lux `match` that misses a case is an error. A Go `switch` that
misses one just does nothing, and Go would then complain that the function might
end without returning a value. The `panic` satisfies Go and stops the program if
that line is ever reached.

Go has no `Option` either. It has `nil`, a value meaning "nothing here" that
pointers, interfaces and slices can all hold. An interface that holds nothing is
`nil`, so the converter uses that for an empty cell:

```go
func mark(cell Player) string {
	if playerOpt := cell; playerOpt != nil {
		...
	} else {
		return "."
	}
}
```

The type says `Player`, not `Option<Player>`, so nothing in the type tells you
the cell might be empty. That's the trade Go makes with `nil`, and a `nil` where
the code expected a real value is one of the most common ways a Go program
crashes. For an `Option<int>`,
where an `int` can't be `nil`, the converter uses a pointer to an `int` instead,
`*int`, and a small `ptr` function to make one.

## 2.4 Why not keep it

The translation works, it's correct, and it plays the game. The reason not to
build on it is that it is lux's program in Go's syntax. Every choice in it is
lux's choice, kept alive by `luxCheck`, `copyBoard`, `ptr` and the interface
cases, and a Go programmer reading it would see a program that keeps fighting the
language it's written in.

Go is a different lineage from lux, and it gives you different tools for the
same jobs. Here is what the board looks like with Go's own:

```go
const (
	Columns = 7
	Rows    = 6
)

type Player int

const (
	Nobody Player = iota
	Red
	Yellow
)

type Board struct {
	cells [Rows][Columns]Player
}
```

Four things changed.

The board's size is a constant. Go has them, so `columns()` becomes `Columns`.

The cells are a fixed-size *array*, `[Rows][Columns]Player`, not a slice. A Go
array is a value: assigning one or passing it to a function copies all of its
elements, just as lux copies. That's the behavior lux taught you, built into the
type, so `copyBoard` disappears. It only works because the board never changes
size. A list that grows, like the sixty-nine winning lines, stays a slice.

A player is a number. `type Player int` makes a new type that is stored as an
`int` but is a different type from `int`, so you can't pass a column where a
player belongs. `iota` counts up inside a `const` block, giving `Nobody` the
value 0, `Red` 1 and `Yellow` 2. This is the usual Go shape for a list of cases
that carry no data; the interface shape the converter used is for cases that do.

And the empty cell is `Nobody`, a player who isn't one. That's the choice
chapter 1 turned down, and in Go it's the right one, because of *zero values*.
Every Go type has one: 0 for numbers, `""` for strings, `false` for booleans,
and for an array, an array of zero values. A variable you declare without a value
starts at its zero value. Since `Nobody` is 0, an empty board is any `Board` you
haven't touched:

```go
var board Board
```

That replaces `emptyBoard()` and its two loops.

What you lose is the check. lux made you handle `none` everywhere a cell could
be empty, and Go won't make you handle `Nobody` anywhere. The program stays
correct the way most Go programs stay correct: by keeping the code that cares
about empty cells in a few small functions, and by testing them.

Rewriting the translation into this shape would mean changing nearly every line
of it. Starting again is less work, and it leaves you with a program you
understand line by line.

## 2.5 A plan in slices

The finished program will play against the computer at three levels, take
commands, save an unfinished game, accept options when it starts, and ship. That
is far too much to write at once and test at the end. Instead, it's built in
*slices*: each slice adds one thing and leaves a complete program behind, one
that builds, passes its tests and runs. If a slice breaks something, the break is
in the last small change.

The slices were planned before any code was written, in a file called `PLAN.md`:

```text
1. A program that runs: prints an empty board and quits on `quit` or end of input.
2. The board: drop a disc into a column, refuse a full one, show the result.
3. Winning and drawing: two players at one terminal, the game the lux version plays.
4. The command loop: help, new game, bad input answered in plain words.
5. A random opponent, with a seed so a game can be replayed.
6. The search: negamax with alpha-beta, scored the way vier-desktop scores.
7. Difficulty: easy, medium and hard, as vier-desktop defines them.
8. Saving: the game in progress survives quitting, as JSON in the user's state directory.
9. Flags and help text: `--seed`, `--level`, `--version`, `--help`.
10. Release: version stamp, packaging for apt and WinGet, shipped through the fleet's release apps.
```

vier-desktop is the Linux desktop version of Vier, and the computer opponent in
this program is built to play the same way it does. The release apps in slice 10
come up in chapter 11. Slice three gets back to where chapter 1 ended. The first two slices are
smaller than anything in the lux program, and that's on purpose. Slice one has
almost no game in it. What it has is everything the game will hang off: a
project, a board that prints, a loop that reads what you type, and tests.

## 2.6 The project

A Go program starts with a module:

```text
mkdir vier-cli
cd vier-cli
go mod init github.com/anderix/vier-cli
```

That writes `go.mod`:

```text
module github.com/anderix/vier-cli

go 1.26.0
```

The first line is the module's name. Naming it after the place its code will
live means `go install github.com/anderix/vier-cli@latest` can find it later,
which is one of the ways people will install this program. The second line is
the version of Go it was written for.

A Go program can be split across as many files as you like. Every file in the
folder that starts with `package main` belongs to the same program and can use
anything the others define, so files are for the reader, not the compiler.
vier-cli puts the board in `board.go` and the conversation in `main.go`.

## 2.7 The board

`board.go` holds the types from section 2.4 and one thing more:

```go
func (p Player) mark() string {
	switch p {
	case Red:
		return "R"
	case Yellow:
		return "Y"
	default:
		return "."
	}
}

// Board holds the discs with row 0 at the bottom, where a dropped disc lands first.
type Board struct {
	cells [Rows][Columns]Player
}

func (b Board) String() string {
	var out strings.Builder
	for row := Rows - 1; row >= 0; row-- {
		for column := range Columns {
			out.WriteString(" " + b.cells[row][column].mark())
		}
		out.WriteString("\n")
	}
	out.WriteString(" 1 2 3 4 5 6 7\n")
	return out.String()
}
```

`mark` and `String` are *methods*: functions that belong to a type. The part in
parentheses before the name, `(p Player)`, is the *receiver*, the value the
method is called on, so `cell.mark()` calls `mark` with `p` set to `cell`. In lux
you'd write `mark(cell)`. A method does the same work; it reads better when the
value comes first, and it lets the method's name be short because the type
already says what it's about.

`mark` uses `default` for every value that isn't `Red` or `Yellow`. That covers
`Nobody`, and it would also cover a `Player` of 7 if one ever appeared, which
`type Player int` doesn't prevent. Go's `switch` doesn't insist on every case,
so `default` is where you decide what happens to the rest.

`String` is a method with a particular name. Go's `fmt` package, which does the
printing, looks for a `String() string` method on any value it's asked to print,
and uses it if it's there. So `fmt.Print(board)` prints the board. A type with a
`String` method is called a *Stringer*, and most Go types meant for people to
read have one.

Inside `String`, a `strings.Builder` collects the text a piece at a time, which
is cheaper than adding strings together over and over. `for row := Rows - 1;
row >= 0; row--` is Go's counting loop, the `while` from lux's `show` written on
one line, and `for column := range Columns` counts from 0 up to 6, as
`for column in 0..columns()` did.

## 2.8 The loop

`main.go` is where the program starts:

```go
package main

import (
	"bufio"
	"fmt"
	"io"
	"os"
	"strings"
)

func main() {
	run(os.Stdin, os.Stdout)
}

func run(in io.Reader, out io.Writer) {
	var board Board
	lines := bufio.NewScanner(in)
	fmt.Fprint(out, board)
	for {
		fmt.Fprint(out, "> ")
		if !lines.Scan() {
			fmt.Fprintln(out)
			return
		}
		switch strings.TrimSpace(lines.Text()) {
		case "quit":
			return
		default:
			fmt.Fprintln(out, "Type quit to leave.")
		}
	}
}
```

The `import` block names the packages from Go's standard library the file uses.
Go refuses to compile a file that imports a package it doesn't use, so the list
is always exactly what the file needs.

`main` does one thing: it calls `run` with the keyboard and the screen. `os.Stdin`
is where typed input comes from and `os.Stdout` is where printed output goes,
the two places lux's `readLine` and `print` used without naming them. `run`
doesn't use them directly. It takes an `io.Reader`, anything that text can be
read from, and an `io.Writer`, anything that text can be written to. Those are
interfaces, and the keyboard and the screen are only one pair of values that
fit them. A string can be read from, and a `strings.Builder` can be written to,
so a test can hand `run` a whole game as a string and read back everything it
printed. Section 2.9 does that.

`bufio.NewScanner` reads its input a line at a time. `lines.Scan()` moves to the
next line and returns `true`, or returns `false` when the input has run out, the
same two answers `readLine` gave with `some` and `none`. When the input ends, the
program prints a newline, so your shell's prompt starts on a line of its own, and
returns.

`for { … }` with nothing after `for` is a loop that runs until something inside
it returns. Go doesn't need `while true`, and it doesn't need the `return` after
the loop that lux needed in `chosenColumn`, because Go knows this loop can only
be left by a `return`.

`fmt.Fprint` and `fmt.Fprintln` are `print` aimed at a particular writer; the
`F` is for file. Unlike lux's `print`, `Fprint` adds no newline, which is what
lets the prompt `> ` sit on the same line as what you type.

The `switch` looks at the line with its surrounding spaces trimmed. `quit` ends
the program, and anything else gets an answer. Slice one knows one command, so
the answer is to type it.

```text
$ go run .
 . . . . . . .
 . . . . . . .
 . . . . . . .
 . . . . . . .
 . . . . . . .
 . . . . . . .
 1 2 3 4 5 6 7
> hello
Type quit to leave.
> quit
$
```

## 2.9 Tests

The lux program was tested by playing it. This one has tests that run in a
fraction of a second, and from here on, every slice adds to them.

Go's tests live in files whose names end in `_test.go`, in the same folder and
the same package as the code. `go build` leaves them out of the program, and
`go test` runs them. A test is a function whose name starts with `Test` and
which takes a `*testing.T`, the value it uses to report a failure:

```go
func TestEmptyBoardShowsSixRowsOfDots(t *testing.T) {
	var board Board
	if got := board.String(); got != emptyBoard {
		t.Errorf("empty board:\n%s\nwant:\n%s", got, emptyBoard)
	}
}
```

`emptyBoard` is a constant in the test file holding the seven lines an empty
board should print. `t.Errorf` marks the test as failed and says why, and the
test goes on, so one run can report several failures.

The board's rows are easy to get upside down, so a second test puts a red disc
in the bottom left and a yellow one in the top right, and checks which line each
lands on:

```go
func TestBottomRowPrintsLast(t *testing.T) {
	var board Board
	board.cells[0][0] = Red
	board.cells[Rows-1][Columns-1] = Yellow
	lines := strings.Split(board.String(), "\n")
	if lines[0] != " . . . . . . Y" || lines[Rows-1] != " R . . . . . ." {
		t.Errorf("rows printed in the wrong order:\n%s", board)
	}
}
```

The rest test the conversation, and this is what `run`'s reader and writer were
for. A helper plays a session from a string and returns everything the program
printed:

```go
func session(input string) string {
	var out strings.Builder
	run(strings.NewReader(input), &out)
	return out.String()
}

func TestQuitEndsTheSession(t *testing.T) {
	if got, want := session("quit\nhello\n"), emptyBoard+"> "; got != want {
		t.Errorf("got %q, want %q", got, want)
	}
}
```

The input has a line after `quit`. If `quit` didn't end the session, the program
would answer `hello` and the output would be longer than it should be. Two more
tests check that running out of input ends the session and that anything else
gets an answer.

```text
$ go test
PASS
ok  	github.com/anderix/vier-cli	0.001s
```

## 2.10 What this slice gives you

This slice is `examples/ch02-runs`. It is about a hundred and fifty lines,
counting the tests, and it can't play a single move. But the parts that aren't
the game are now in place: a module, a board type that prints itself, a loop that
reads and answers lines and stops when it should, and tests that drive the whole
program the way a person would. Chapter 3 puts discs on the board.
