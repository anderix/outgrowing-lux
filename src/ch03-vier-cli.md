# 3. vier-cli

vier-cli is the Go version of Vier, written by hand the way a Go programmer
writes Go. It plays in a terminal against the computer or a friend, it
remembers a game you haven't finished, and it has tests that check it works.
It's about fifteen hundred lines counting its tests, and nine hundred without
them, between four and five times the size of your lux game.

You won't read all of them. This chapter gets the program running, finds the
five pieces from chapter 1 inside it, and then follows one move from the moment
you type it to the moment the computer answers. Along the way you'll meet the
few Go ideas the program is built on. By the end you'll know how vier-cli works,
even though you've skipped most of its lines.

## 3.1 Running it

Get the code and run it:

```text
git clone https://github.com/anderix/vier-cli
cd vier-cli
go run .
```

`git clone` copies the program's repository onto your computer, and `go run .`
builds it and starts it. You play Red against the computer, and it answers each
move. It plays some of its moves at random, so your game won't match this one:

```text
A new game against the easy computer.
 . . . . . . .
 . . . . . . .
 . . . . . . .
 . . . . . . .
 . . . . . . .
 . . . . . . .
 1 2 3 4 5 6 7
Red> 4
 . . . . . . .
 . . . . . . .
 . . . . . . .
 . . . . . . .
 . . . . . . .
 . . . R . . .
 1 2 3 4 5 6 7
The computer plays 2.
 . . . . . . .
 . . . . . . .
 . . . . . . .
 . . . . . . .
 . . . . . . .
 . Y . R . . .
 1 2 3 4 5 6 7
Red> 9
There is no column 9. The columns are 1 to 7.
Red> hello
I don't know "hello". Type help for the commands.
Red>
```

Type `help` to see what else it understands: `friend` starts a game for two
players, `easy`, `medium` and `hard` change how well the computer plays, and
`quit` leaves. If you quit halfway through a game and start it again, it picks
up where you left off.

`go build` makes a program file you can run without Go, called `vier-cli`, and
`go test` runs the tests. Section 3.9 comes back to those.

## 3.2 Finding the pieces

Here are the files, with the tests left out:

```text
board.go     the board, the players, the rules
game.go      one game: the board, whose turn it is, and how it ended
session.go   the conversation: commands, the computer's turn, saving
engine.go    how the computer picks a move
rng.go       random numbers for the computer
memory.go    the saved game and the choices you made, kept in a file
options.go   options you can give when you start it, like --level hard
version.go   the version number it prints
main.go      where it starts
```

A Go program can be spread across as many files as the author likes, and every
file in the folder is part of the same program. The files are there for you,
the reader, so you can find things.

Now match them to the map from chapter 1:

| Piece | lux | vier-cli |
|---|---|---|
| The board | `Board`, `Option<Player>` cells | `Board` in board.go |
| The rules | `canDrop`, `dropped`, `winner`, `isFull` | `CanDrop`, `Drop`, `Winner`, `Full` in board.go |
| The turn | the `turn` variable | `Turn` in game.go |
| The loop | the `while !done` loop | `Serve` in session.go |
| The display | `show` | `String` in board.go |

Everything else is what vier-cli has that your game doesn't: a computer
opponent, saving, and options. The computer and saving each get a section
later. You could skip all three and still understand the game.

## 3.3 The board

Open board.go. Near the top:

```go
const (
	Columns = 7
	Rows    = 6
)
```

Go has constants, so `columns()` and `rows()` become `Columns` and `Rows`.

```go
type Player int

const (
	Nobody Player = iota
	Red
	Yellow
)
```

This is the simpler way to write a list of cases that chapter 2 promised. Each
player is a number with a name: `Nobody` is 0, `Red` is 1 and `Yellow` is 2.
`iota` is Go's way of counting them off, so you don't have to write the numbers.
Read it as an enum with three cases.

Three, not two. vier-cli has a player called `Nobody`, and an empty cell holds
`Nobody`. Chapter 1 turned that idea down, because every function that takes a
`Player` would have to decide what to do with one who isn't a player. Go makes a
different trade, because of an idea lux doesn't have: every Go value starts out
as zero until you give it something else. A number starts at 0, a string starts
empty, and a board starts with every cell at 0, which is `Nobody`. So this is an
empty board:

```go
var board Board
```

What Go gives up is the reminder you had in lux, where the type
`Option<Player>` told you a cell could be empty. What it gets is a board that's
ready to use the moment it exists.

The board itself:

```go
type Board struct {
	cells [Rows][Columns]Player
}
```

It's the same struct as yours: rows of cells. The sizes in the brackets make it
an array of exactly six rows of seven, which is also why it behaves like a lux
board. Hand it to a function and the function gets a copy, so chapter 2's
`copyBoard` isn't needed here.

## 3.4 Methods

The rules are in board.go too, but they look a little different from functions:

```go
func (b Board) CanDrop(column int) bool {
	return column >= 0 && column < Columns && b.cells[Rows-1][column] == Nobody
}
```

This is a *method*: a function that belongs to a type. The board goes in the
parentheses before the name instead of in the list after it, and you call it
with the board first:

```go
board.CanDrop(3)
```

Read that as `canDrop(board, 3)`, and read the method as:

```lux
func canDrop(b: Board, column: int) -> bool
```

It's the same function as yours, on one line instead of four. Most of the
functions in vier-cli are methods, and the reading rule is always the same: the
value before the dot is the first thing passed in.

Some names start with a capital letter, like `CanDrop`, and some don't, like
`at`. In a larger Go project, that decides which names other parts of the
project can use. In a program this size it doesn't change anything, and you can
read past it.

## 3.5 Changing the original

Here is how a disc is dropped:

```go
func (b *Board) Drop(column int, p Player) (int, error) {
	if column < 0 || column >= Columns {
		return 0, ErrNoSuchColumn
	}
	for row := range Rows {
		if b.cells[row][column] == Nobody {
			b.cells[row][column] = p
			return row, nil
		}
	}
	return 0, ErrColumnFull
}
```

There are two new things here. The first is the star in `*Board`.

In lux, `dropped` couldn't change your board, because it got a copy. So it
changed the copy and handed it back, and you kept it:

```lux
board = dropped(board, turn, column)
```

Go can do it that way too, but it has another option. A method whose board has
a star in front of it gets the board itself, not a copy, and what it changes
stays changed. So vier-cli drops a disc like this:

```go
board.Drop(column, player)
```

and afterwards, `board` has the new disc in it. Same job, two ways of doing it.
When you're reading Go, a star in front of a type means "the original, not a
copy". A method with a star changes the value you call it on. A method without
one, like `CanDrop`, only looks at it.

That's also the star you saw in chapter 2. A starred value reaches one value
that lives somewhere else, and it can also be `nil`, reaching nothing. The
converter used that second part for "an `int` that might be missing". vier-cli
uses the first part, to change the board in place.

## 3.6 Two answers at once

The second new thing in `Drop` is `(int, error)`. A Go function can hand back
more than one value, and this one hands back two: the row the disc landed in,
and an error, which says what went wrong.

You've met this idea before, as `Result`. A lux function that might fail
returns `ok(value)` or `err(problem)`. Go returns both every time, and one of
them means "nothing":

| Go | lux |
|---|---|
| `return row, nil` | `return ok(row)` |
| `return 0, ErrColumnFull` | `return err("column is full")` |

When it works, the error is `nil`. When it fails, the row is 0, which means
nothing, and the error says why. The code that calls `Drop` checks the error
first:

```go
if _, err := g.Board.Drop(column, g.Turn); err != nil {
	return err
}
```

Read `if err != nil` as the `err` arm of a `match`. The `_` means "I don't need
this value", which here is the row. You'll see `if err != nil` all through Go
code. It's how Go programs handle a step that can fail, and like `nil` itself,
nothing makes you write it; Go programmers write it out of habit.

## 3.7 The game and the turn

In chapter 1, the state of the game was three variables at the top of the main
loop: the board, whose turn it was, and whether the game was over. vier-cli
gathers them into a struct in game.go:

```go
type Game struct {
	Board  Board
	Turn   Player
	Winner Player
	Over   bool
}
```

The body of your main loop, the part that makes a move and checks for the end,
became a method:

```go
func (g *Game) Play(column int) error {
	if g.Over {
		return ErrGameOver
	}
	if _, err := g.Board.Drop(column, g.Turn); err != nil {
		return err
	}
	g.Winner = g.Board.Winner()
	g.Over = g.Winner != Nobody || g.Board.Full()
	if !g.Over {
		g.Turn = g.Turn.opponent()
	}
	return nil
}
```

Read it next to your loop. It drops the disc, asks for a winner, decides whether
the game is over, and passes the turn. Every step is one you wrote. The only
difference is that when the game ends, vier-cli doesn't pass the turn, so the
winner is still the one whose turn it is.

## 3.8 The loop, and one move through it

The loop is `Serve`, in session.go:

```go
func (s *Session) Serve(in io.Reader) {
	lines := bufio.NewScanner(in)
	for {
		fmt.Fprint(s.out, s.prompt())
		if !lines.Scan() {
			fmt.Fprintln(s.out)
			return
		}
		command := strings.ToLower(strings.TrimSpace(lines.Text()))
		switch command {
		case "":
		case "quit":
			return
		case "help":
			fmt.Fprint(s.out, help)
		...
		default:
			s.play(command)
		}
	}
}
```

It's chapter 1's loop with more to say. It prints a prompt, reads a line, and
stops if there are no more lines, as your `readLine` returning `none` did. Then
it looks at what you typed. A command it knows gets an answer. Anything else
goes to `play`, which tries it as a column.

A `Session` is everything that lasts from one game to the next: the game in
progress, the level you chose, and where to save. `s` is the session, and
`s.out` is where it prints, which is normally the screen. The rest of this
section follows `4` from the keyboard to the computer's reply.

`Serve` reads `4`, doesn't recognize it as a command, and calls `play`:

```go
func (s *Session) play(command string) {
	number, err := strconv.Atoi(command)
	if err != nil {
		fmt.Fprintf(s.out, "I don't know %q. Type help for the commands.\n", command)
		return
	}
	if err := s.game.Play(number - 1); err != nil {
		fmt.Fprintln(s.out, refusal(err, number))
		return
	}
	fmt.Fprint(s.out, s.game.Board)
	s.announce()
	s.computerTurn()
	s.save()
}
```

`strconv.Atoi` is Go's `parseInt`, and it answers with two values too: the
number, or an error if what you typed wasn't one. `hello` stops here. `4`
doesn't, and becomes column 3, counted from 0 as in chapter 1.

`s.game.Play(3)` is the method from section 3.7. It drops the disc, checks for a
winner, and passes the turn to Yellow. If the column was full or doesn't exist,
it returns an error instead, and `refusal` turns the error into a sentence like
"There is no column 9."

`fmt.Fprint(s.out, s.game.Board)` prints the board. That works because `Board`
has a method called `String`, and Go's printing functions look for one on
anything they're asked to print. `String` in board.go is your `show`, building
the same lines from the top row down.

`announce` prints the result if the game just ended. `computerTurn` gives the
computer its move, which section 3.10 opens up. `save` writes the game to a file,
which is section 3.11.

A move's route, then, is `Serve` → `play` → `Game.Play` →
`Board.Drop` → back up to print the board → `computerTurn` → `save`. If you
know that route, you know how vier-cli works. Everything else in the program
hangs off it.

## 3.9 How you know it works

Your lux game was tested by playing it. vier-cli has tests, in the files ending
in `_test.go`, and `go test` runs them. With `-v`, it lists each one by name:

```text
$ go test -v
=== RUN   TestDiscsStackFromTheBottom
--- PASS: TestDiscsStackFromTheBottom (0.00s)
=== RUN   TestAFullColumnRefusesADisc
--- PASS: TestAFullColumnRefusesADisc (0.00s)
=== RUN   TestOnlySevenColumnsExist
--- PASS: TestOnlySevenColumnsExist (0.00s)
=== RUN   TestPlayersTakeTurns
--- PASS: TestPlayersTakeTurns (0.00s)
=== RUN   TestThereAre69WinningLines
--- PASS: TestThereAre69WinningLines (0.00s)
=== RUN   TestFourInALineWins
--- PASS: TestFourInALineWins (0.00s)
...
```

The names read like the rules of the game. When you open
a program you don't know, the test names are one of the best places to start:
they're a list of what the program promises, written by the person who made it.

A test is a small program that plays part of the game and checks the result.
This one plays a few short games and checks who won each:

```go
func TestFourInALineWins(t *testing.T) {
	for _, game := range []struct {
		name    string
		columns []int
		winner  Player
	}{
		{"across", []int{1, 1, 2, 2, 3, 3, 4}, Red},
		{"up", []int{1, 2, 1, 2, 1, 2, 7, 2}, Yellow},
		{"rising diagonal", []int{1, 2, 2, 3, 3, 4, 3, 4, 4, 1, 4}, Red},
		{"falling diagonal", []int{7, 6, 6, 5, 5, 4, 5, 4, 4, 7, 4}, Red},
		{"three is not four", []int{1, 1, 2, 2, 3, 3}, Nobody},
	} {
		if got := played(t, game.columns...).Winner(); got != game.winner {
			t.Errorf("%s: got %s, want %s", game.name, got, game.winner)
		}
	}
}
```

You don't need every detail to read it. It's a list of games, each with a name,
the columns played in order, and who should win, and a loop that plays each one
and complains if the winner is wrong.

> try: in board.go, change `mark` to return `"X"` for Red instead of `"R"`,
> and run `go test`. Read which tests fail and what each one says. Every
> failure is about what the board looks like on the screen, because that's all
> you changed. Change it back when you're done.

## 3.10 The computer

The computer's move comes from `BestMove` in engine.go. You can understand what
it does without following how, and that's enough to read the rest of the
program. It works through four questions, in order:

1. Can I win with this move? Then play it.
2. Can my opponent win with their next move? Then block it, unless I'm the easy
   computer.
3. Should I play a random column instead of thinking? The easy computer does
   that about two times in three, the medium one about half the time, and the
   hard one never.
4. Otherwise, look ahead.

Looking ahead means trying every column, then every reply the opponent could
make to it, then every answer to that, and so on: one move deep for the easy
computer, two for medium, and four for hard. When it stops looking, it scores
each board it reached with `evaluate`, which counts things that tend to win:
discs in the middle column, and three or two in a line with room to finish
them. Then it picks the column that leads to the best score, assuming the
opponent always picks their best reply too.

Trying a move means dropping a disc on a copy of the board, and here your lux
habit pays off:

```go
next := board
row, err := next.Drop(column, player)
```

`next := board` copies the board, because a Go array is copied when you assign
it, just as lux copies. The computer changes `next` and leaves the real board
alone.

## 3.11 Remembering

After every move, `save` writes the game to a file. On Linux it's
`~/.local/state/vier-cli/state.json`:

```text
{
  "mode": "computer",
  "difficulty": "easy",
  "nextStarter": "yellow",
  "savedGame": {
    "board": [
      ".......",
      ".......",
      ".......",
      "...Y...",
      "...R...",
      ".Y.R..."
    ],
    "turn": "red"
  }
}
```

This format is called JSON, and many programs use it to keep data in a file
that people can read as well. You can see the board in it, top row first, the
way the game prints it. The letters look like the screen's, but they're kept
separately, in memory.go, so a change to how the discs are drawn can't make a
saved game unreadable. That's the exercise from section 3.9 again: change
`mark`, and the saving tests still pass. When vier-cli starts, it reads this file back, and if
there's an unfinished game, it says "Picking up where you left off." The code
that turns the board into those six lines and back is in memory.go.

## 3.12 What you found

You opened a Go program of fifteen hundred lines and found your game inside it.
The board is a struct of cells, and the rules are methods on it. The turn lives
in `Game`, the loop is `Serve`, and the display is `String`. A move travels
through a handful of functions you can name. The parts you skipped, the search,
the saving and the options, each do one job, and you know which job.

The Go ideas you needed were few. Methods put the value before the dot. A star
means the original instead of a copy. Two return values, with `if err != nil`,
do the job of `Result`. And every value starts at zero. With those and the
reading table from chapter 2, you can open most small Go programs and find your
way around.

One thing about vier-cli is the same as your lux game, and it's about to stop
being true. vier-cli runs the loop itself: `Serve` reads a line, answers it, and
goes around again, and nothing happens unless `Serve` makes it happen. The next
two apps don't work that way. In a window or on a phone, something else runs
the loop, and your code waits to be called. Chapter 4 shows what that means, in
lux.
