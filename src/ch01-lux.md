# 1. Four in a Row in Lux

Before this program can become anything else, it has to work. This chapter
writes Vier in lux: two players at one keyboard, taking turns, until one of
them lines up four or the board fills. It is about two hundred lines, it uses
nothing lux doesn't already give you, and every chapter after this one starts
from it.

Here is the start of a game. Red drops a disc into column 4, Yellow drops one
on top of it, and Red plays column 5:

```text
$ lux run vier.lux
 . . . . . . .
 . . . . . . .
 . . . . . . .
 . . . . . . .
 . . . . . . .
 . . . . . . .
 1 2 3 4 5 6 7
Red, pick a column (1-7):
4
 . . . . . . .
 . . . . . . .
 . . . . . . .
 . . . . . . .
 . . . . . . .
 . . . R . . .
 1 2 3 4 5 6 7
Yellow, pick a column (1-7):
4
 . . . . . . .
 . . . . . . .
 . . . . . . .
 . . . . . . .
 . . . Y . . .
 . . . R . . .
 1 2 3 4 5 6 7
Red, pick a column (1-7):
5
```

The full program is `examples/ch01-lux/vier.lux`. This chapter goes through it
in the order you'd write it: first the data, then the rules, then the part that
talks to the players.

## 1.1 What a board is

A game is mostly a board, so the first decision is what a board holds. Each of
its forty-two cells is either empty or holds one player's disc. Players are an
enum with two cases:

```lux
enum Player {
    red
    yellow
}
```

and a cell is an `Option<Player>`: `some(Player.red)`, `some(Player.yellow)`, or
`none`. That last one is the empty cell. You could add a third case to `Player`
called `nobody`, and some programs do, but then every function that takes a
`Player` has to decide what to do with a player who isn't one. `opponent` would
need an answer for `nobody`, and so would `name`. With `Option`, the type says
which values can be empty, and `match` makes you handle the empty case only in
the places where it can actually happen.

The board is a struct holding rows of cells:

```lux
struct Board {
    cells: [[Option<Player>]]
}
```

Row 0 is the bottom of the board. A dropped disc lands in the lowest empty row,
so counting from the bottom makes "the lowest empty row" the first `none` you
find going up. Printing is the only thing that wants the top row first, and it
can count down.

The board's size shows up in a lot of places, so it gets a name. lux has no
constants, but a function that returns a number does the same job:

```lux
func columns() -> int {
    return 7
}

func rows() -> int {
    return 6
}
```

An empty board is six rows of seven `none`s, built with two loops:

```lux
func emptyBoard() -> Board {
    var cells: [[Option<Player>]]
    for row in 0..rows() {
        var line: [Option<Player>]
        for column in 0..columns() {
            line += none
        }
        cells += line
    }
    return Board(cells: cells)
}
```

## 1.2 Dropping a disc

A move is a column. Before anything else, the program has to know whether a
column can take another disc. It can if the column exists and its top cell is
still empty:

```lux
func at(board: Board, column: int, row: int) -> Option<Player> {
    return board.cells[row][column]
}

func canDrop(board: Board, column: int) -> bool {
    if column < 0 || column >= columns() {
        return false
    }
    return at(board, column, rows() - 1) == none
}
```

The range check comes first because `at` with a column of 9 would stop the
program with an index error. `canDrop` is the one place that decides what a
legal move is, so the rest of the program can ask it instead of checking indexes
itself.

The disc lands in the lowest empty cell of the column:

```lux
func landingRow(board: Board, column: int) -> int {
    var row = 0
    while at(board, column, row) != none {
        row += 1
    }
    return row
}
```

That loop would run off the top of a full column, which is why nothing calls it
without asking `canDrop` first.

Then the move itself:

```lux
func dropped(board: Board, player: Player, column: int) -> Board {
    var next = board
    next.cells[landingRow(board, column)][column] = some(player)
    return next
}
```

`dropped` doesn't change the board it was given. It copies it, changes the copy,
and hands the copy back, because in lux `var next = board` makes a copy. The
caller decides what to do with the new board, and in this program the caller
keeps it: `board = dropped(board, turn, column)`. If you forget the `board =`,
nothing happens to the game, and `lux trace` will show you a board that never
changes. Keep that copy in mind. It comes back in the next chapter, when the
program moves to a language that copies some things and not others.

## 1.3 Four in a line

A line is four cells in a row: across, up, or along either diagonal. There are
sixty-nine of them on a seven-by-six board, and the program could look for them
fresh after every move, but the lines are the same in every game. So the program
works them out once, as positions, and checks those.

```lux
struct Position {
    column: int
    row: int
}
```

Every line has a starting cell and a direction. The directions are steps: one
column right, one row up, one of each, or one column right and one row down. A
line fits on the board if its fourth cell, three steps from the start, is still
inside:

```lux
func inside(column: int, row: int) -> bool {
    return column >= 0 && column < columns() && row >= 0 && row < rows()
}

func winningLines() -> [[Position]] {
    let steps = [[1, 0], [0, 1], [1, 1], [1, -1]]
    var all: [[Position]]
    for column in 0..columns() {
        for row in 0..rows() {
            for step in steps {
                if inside(column + step[0] * 3, row + step[1] * 3) {
                    var line: [Position]
                    for i in 0..4 {
                        line += Position(column: column + step[0] * i, row: row + step[1] * i)
                    }
                    all += line
                }
            }
        }
    }
    return all
}
```

There are only four directions, not eight, because a line from left to right is
the same line as the one from right to left. Counting each direction once means
each line is found once.

A line belongs to a player if all four of its cells hold that player's disc.
`owner` reads the first cell and then checks that the other three match it:

```lux
func owner(board: Board, line: [Position]) -> Option<Player> {
    let first = at(board, line[0].column, line[0].row)
    for cell in line {
        if at(board, cell.column, cell.row) != first {
            return none
        }
    }
    return first
}
```

If the first cell is empty, `first` is `none`, and the line comes back `none`
whether the other three are empty or not. That's the right answer: four empty
cells don't belong to anyone.

`winner` asks every line:

```lux
func winner(board: Board, candidates: [[Position]]) -> Option<Player> {
    for line in candidates {
        let found = owner(board, line)
        if found != none {
            return found
        }
    }
    return none
}
```

The parameter is called `candidates` rather than `lines` because a lux name can
belong to a function or to a variable, but not to both at once, and an earlier
draft of this program had a function called `lines`. The error lux gives for
that, "`lines` is already the name of a function", is a fair complaint: in a
long function you'd have to stop and work out which `lines` a line meant.

A draw is a full board with no winner. The board is full when no column can take
another disc:

```lux
func isFull(board: Board) -> bool {
    for column in 0..columns() {
        if canDrop(board, column) {
            return false
        }
    }
    return true
}
```

## 1.4 Talking to the players

The rest of the program is the conversation. Each player needs a name and each
cell a mark:

```lux
func name(player: Player) -> string {
    return match player {
        red => "Red"
        yellow => "Yellow"
    }
}

func mark(cell: Option<Player>) -> string {
    return match cell {
        some(let player) => match player {
            red => "R"
            yellow => "Y"
        }
        none => "."
    }
}
```

`mark` takes the cell apart twice: once to see whether there is a disc, and once
to see whose it is. A `match` arm in lux holds one expression, and another
`match` counts as one, so the nested form is how you say "look inside the
`some`".

`show` prints the rows from the top down and the column numbers underneath, so
the players can see which number goes with which column:

```lux
func show(board: Board) {
    var row = rows() - 1
    while row >= 0 {
        var text = ""
        for column in 0..columns() {
            text += " " + mark(at(board, column, row))
        }
        print(text)
        row -= 1
    }
    print(" 1 2 3 4 5 6 7")
}
```

Reading a move is where the program meets the outside world, and the outside
world doesn't always cooperate. A player might type `9`, or `four`, or nothing
at all. The input might also run out, which happens when you pipe a file
of moves into the program instead of typing them. `input` turns the end of input
into an empty string, so a program reading moves with `input` would ask for a
column forever once the moves ran out. `readLine` keeps the difference: it
returns `some(line)` while there are lines and `none` when there aren't.

```lux
func columnFrom(line: Option<string>) -> int {
    return match line {
        some(let text) => match parseInt(text) {
            some(let n) => n - 1
            none => -1
        }
        none => -1
    }
}
```

`columnFrom` turns what the player typed into a column index. Players count
columns from 1, and the board counts them from 0, so it subtracts one. Anything
that isn't a number becomes -1, which `canDrop` rejects like any other column
that isn't on the board.

`chosenColumn` asks until it gets a column it can use, or until the input runs
out:

```lux
func chosenColumn(board: Board, player: Player) -> Option<int> {
    while true {
        print(name(player) + ", pick a column (1-7):")
        let line = readLine()
        if line == none {
            return none
        }
        let column = columnFrom(line)
        if canDrop(board, column) {
            return some(column)
        }
        print("That column is not open.")
    }
    return none
}
```

It returns `Option<int>` because "the player picked column 3" and "there is no
player any more" are different answers, and the main loop needs to tell them
apart. The `return none` after the loop never runs. It's there because lux
checks that every path through a function returns a value, and it doesn't treat
`while true` as a loop that never ends.

## 1.5 The game

The main program holds the state of the game in three variables, the board,
whose turn it is, and whether the game is over, and loops until it is:

```lux
let allLines = winningLines()
var board = emptyBoard()
var turn = Player.red
var done = false
while !done {
    show(board)
    let choice = chosenColumn(board, turn)
    if choice == none {
        done = true
    } else {
        board = match choice {
            some(let column) => dropped(board, turn, column)
            none => board
        }
        let result = winner(board, allLines)
        if result != none || isFull(board) {
            show(board)
            print(match result {
                some(let player) => name(player) + " wins!"
                none => "A draw."
            })
            done = true
        }
        turn = opponent(turn)
    }
}
```

`opponent` is the last piece, a `match` that swaps the two players.

The `match choice` has a `none` arm that can't happen, since the `if` above it
already handled `none`. A `match` has to cover every case, even one the code
around it has ruled out. Chapter 2 will look at what other languages do instead.

When Red completes a line of four, the game ends:

```text
 . . . . . . .
 . . . . . . .
 . . . R . . .
 . . . R Y . .
 . . . R Y . .
 . . . R Y . .
 1 2 3 4 5 6 7
Red wins!
```

## 1.6 The map

The game works. Two people at one keyboard can play it to the end, and it
handles every column they can type. It's also small enough that you can hold
all of it in your head, and that's what makes it useful for the rest of this
book. Every version of Vier has the same pieces, and you've now written each of
them:

- **The board.** It holds a disc or nothing in each cell, and it can say which.
- **The rules.** They decide which moves are allowed, where a disc lands, and
  when the game is won or drawn.
- **The turn.** It says whose move it is, and it passes to the other player
  after each one.
- **The loop.** It asks for a move, makes it, checks for the end, and goes
  around again.
- **The display.** It turns the board into something a person can see.

The real apps you'll read have more than this. They have a computer to play
against, they remember a game you haven't finished, and two of them draw the
board in a window instead of in text. But each of them has these five pieces at
its center, under different names and in a different language. When you open
one, the first job is to find them.

Before you open any of them, try one more command:

```text
lux convert go vier.lux > vier.go
```

lux can translate this program into Go, and into Rust and Swift too, and the
translation runs. Chapter 2 starts by reading it.
