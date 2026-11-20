# 4. Who Runs the Loop

Your lux game and vier-cli share one habit. Each runs its own loop: show the
board, wait for a line, make the move, go around again. While the program
waits for that line, nothing else happens, and nothing needs to. A terminal is
patient.

A window isn't. While you decide where to play, the window still has to answer
the mouse, draw the column you're pointing at, and repaint itself when another
window moves off it. If the program stopped to wait for your click the way
vier-cli stops to wait for a line, the window would freeze. So programs with
windows hand the loop to someone else, and both of the remaining apps in this
book are built that way. This chapter shows what that means, in lux, before
you meet it in Rust.

## 4.1 A program someone else runs

lux has a lesson on this. Run `lux learn host`. It describes a program run by
another program, called a *host*. The host loads your file, and then it calls
your functions whenever it needs them, hands them values, and keeps what they
hand back. Your file holds only declarations, structs, enums and functions,
with no lines at the top level, because the host decides when anything runs.

The host for a program with a window is usually a *framework*: a library that
runs the loop and calls code you wrote at the right moments. vier-desktop's
framework is called eframe, and vier-ios's is SwiftUI. The loop a framework
runs is called the *event loop*. An *event* is something that happened, like
a click, a key or the mouse moving, and each time around, the loop collects the
events, lets your code respond to them, and draws the window again. One pass
around the loop is a *frame*, the same word as one picture in a film, because
that's what each pass produces.

So the question this chapter asks of Vier is: if you can't write the loop, what
do you write instead?

## 4.2 Vier for a host

The game shaped for a host is in `examples/ch04-host/vier.lux`. The board and
the rules are chapter 1's, unchanged: `emptyBoard`, `canDrop`, `dropped`,
`winner` and `isFull` are copied over line for line. Rules don't care who runs
the loop.

What goes is everything that talked to the terminal. `chosenColumn` and
`readLine` are gone, because the host does the reading. The `while !done` loop
is gone, because the host does the looping. And `show`, which printed the
board, becomes `picture`, which builds the same text and returns it, because
the host does the drawing too.

What's left is four functions the host calls:

```lux
func fresh() -> Game
func clicked(game: Game, column: int, now: float) -> Game
func tick(game: Game, now: float) -> Game
func draw(game: Game) -> string
```

`fresh` makes a new game. `clicked` is called when you click a column. `tick`
is called on every frame, whether anything happened or not. `draw` is called
on every frame too, and what it returns goes on the screen. Each one takes the
game and, except for `draw`, hands back a new game, the way `dropped` takes a
board and hands back a new one. The host keeps the game between calls. Your
code never holds on to anything.

A function you write for someone else to call is often called a *callback*,
because the host calls back into your code. These four are the game's
callbacks.

## 4.3 The game can't wait

The game in this chapter has a computer opponent, a simple one that takes the
first open column it finds counting out from the middle. In vier-cli, the
computer moved inside `play`: you typed a column, your disc dropped, the
computer picked its column, and its disc dropped, all before `play` returned.

In a window you'd want something between those steps. Your disc should land,
the computer should seem to think for a moment, and then its disc should land.
In vier-cli, a pause would be easy: wait half a second, then move. Under a
host it's impossible. While your function runs, the host is waiting for it, so
it can't draw a frame or answer the mouse. A pause inside `clicked` would
freeze the window for as long as the pause lasted.

So the game can't wait. It writes down what it's waiting for, returns, and
checks again on the next frame. That's what the `Phase` enum is for:

```lux
enum Phase {
    yourTurn
    computerThinking(column: int, dueAt: float)
    finished(message: string)
}

struct Game {
    board: Board
    phase: Phase
}
```

`Phase` replaces chapter 1's `turn` and `done`. The game is either waiting for
your click, or waiting for the computer's move, or over. The middle case
carries the computer's column, chosen already, and the time it's due. Time has
become part of the game's data, the same as the board.

An enum like this, with a case for each situation the program can be in and
rules for moving from one case to the next, is called a *state machine*. Most
programs with windows have one, even when nobody gives it that name.

Here is how a click moves the game from one case to the next:

```lux
func clicked(game: Game, column: int, now: float) -> Game {
    let waiting = match game.phase {
        yourTurn => true
        _ => false
    }
    if !waiting || !canDrop(game.board, column) {
        return game
    }
    let board = dropped(game.board, Player.red, column)
    let thinking = Phase.computerThinking(column: computerColumn(board), dueAt: now + 0.5)
    return afterDrop(board, thinking)
}
```

A click only counts if it's your turn and the column is open. Otherwise the
game comes back unchanged. A counted click drops your disc and sets the
computer thinking, due half a second from `now`. `afterDrop` checks whether
that disc won or filled the board, and if it did, the game is `finished`
instead.

`now` is the time, in seconds, and the host passes it in. Your code has no
clock of its own, for the same reason it has no `readLine`: anything from the
outside world comes from the host.

Then each frame, `tick` checks whether the computer's time has come:

```lux
func tick(game: Game, now: float) -> Game {
    return match game.phase {
        computerThinking(let column, let dueAt) => computerMove(game, column, dueAt, now)
        _ => game
    }
}

func computerMove(game: Game, column: int, dueAt: float, now: float) -> Game {
    if now < dueAt {
        return game
    }
    return afterDrop(dropped(game.board, Player.yellow, column), Phase.yourTurn)
}
```

On most frames, nothing has changed, and `tick` hands the game back as it was.
On the first frame at or after `dueAt`, the computer's disc drops and it's your
turn again. The second function is there because a `match` arm in lux holds a
single expression, and the time check needs an `if`.

## 4.4 Drawing from the game

`draw` builds the whole screen from the game, every time:

```lux
func draw(game: Game) -> string {
    let status = match game.phase {
        yourTurn => "Your turn."
        computerThinking(let _, let _) => "The computer is thinking..."
        finished(let message) => message
    }
    return picture(game.board) + "\n" + status
}
```

It doesn't remember what it drew last time, and it doesn't change anything. It
reads the game and describes it. If the screen is wrong, the game is wrong, or
`draw` is, and there's nowhere else to look. That habit, building the screen
fresh from the state on every frame, is how both of the next two apps draw.

## 4.5 Being the host

With no host, nothing calls these functions. Delete the last lines of the file
and run it, and it prints nothing, which is the shape `lux learn host`
describes. With the last lines in, you're the host:

```lux
var game = fresh()
var shown = ""
for frame in 0..30 {
    let now = float(frame) / 10.0
    if frame == 2 {
        game = clicked(game, 3, now)
    }
    if frame == 12 {
        game = clicked(game, 4, now)
    }
    game = tick(game, now)
    let screen = draw(game)
    if screen != shown {
        print("frame", frame)
        print(screen)
        shown = screen
    }
}
```

This is an event loop. It runs thirty frames, ten to a second, so `now` goes
from 0.0 to 2.9. A real host would get clicks from the mouse; this one makes
two up, a click on column 4 at frame 2 and on column 5 at frame 12. Every frame
it calls `tick` and `draw`, and to keep the output short, it prints the screen
only when it changed:

```text
$ lux run vier.lux
frame 0
 . . . . . . .
 . . . . . . .
 . . . . . . .
 . . . . . . .
 . . . . . . .
 . . . . . . .
 1 2 3 4 5 6 7
Your turn.
frame 2
 . . . . . . .
 . . . . . . .
 . . . . . . .
 . . . . . . .
 . . . . . . .
 . . . R . . .
 1 2 3 4 5 6 7
The computer is thinking...
frame 7
 . . . . . . .
 . . . . . . .
 . . . . . . .
 . . . . . . .
 . . . Y . . .
 . . . R . . .
 1 2 3 4 5 6 7
Your turn.
frame 12
...
```

The click at frame 2 drops your disc and sets the computer's move due at 0.7.
Frames 3 to 6 call `tick` and `draw` and get the same screen back, so nothing
prints. At frame 7, `tick` finds the time has come, and the computer's disc
appears. Frame 12 does it all again.

Nothing in the game ever waited. Every call returned at once, and the half
second passed in the host, between calls.

> try: change `now + 0.5` to `now + 2.0` and run it again. The computer now
> answers at frame 22, and your click at frame 12 does nothing, because it
> came while the computer was still thinking. `clicked` looked at the phase,
> saw it wasn't your turn, and handed the game back unchanged. Change it back
> when you're done.

A real host doesn't always draw at a steady ten frames a second. Some draw as
often as the screen can show a new picture, sixty times a second or more. Some
draw a frame only when something happens, a click or a mouse move, and a
program waiting on a time like `dueAt` can ask to be called again when it
arrives. vier-desktop's host works that second way. Your functions are the same
either way: they take the game and the time, and hand back a game.

## 4.6 The map, under a host

Here are chapter 1's five pieces again, as they are in this version:

| Piece | Chapter 1 | Under a host |
|---|---|---|
| The board | `Board` | `Board`, unchanged |
| The rules | `canDrop`, `dropped`, `winner`, `isFull` | unchanged |
| The turn | `turn` and `done` | `Phase`, which also holds what the game is waiting for |
| The loop | `while !done` | the host's; you write `clicked` and `tick` |
| The display | `show`, which prints | `draw`, which returns the screen for the host to show |

The board and the rules came through untouched. The turn grew into a state
machine with time in it, the loop moved out of your program, and the display
stopped printing and started describing.

That's the shape of vier-desktop. Its framework calls a function named `ui` on
every frame. `ui` passes the time to the game, which checks for a step whose
time has come, as `tick` does. Then it draws the board from the game, and if
you clicked a column, the click goes to the game, as `clicked` does. There's
more of it, in a different language, but it's the program you just ran.
Chapter 5 opens it.
