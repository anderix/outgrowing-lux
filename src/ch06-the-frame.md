# 6. The Frame

Chapter 5 read the parts of vier-desktop that would make sense with no window.
This chapter reads the rest: how the program starts, what it does on every
frame, and what happens between your click and the computer's answer. You've
seen all of it before, in chapter 4, in about a hundred lines of lux. Here it's
in Rust, with more going on, but the shape is the same: something else runs the
loop, the game keeps track of time, and the screen is drawn from the game.

## 6.1 Where it starts

A Rust program starts at `main`, like a Go program. vier-desktop's is in
main.rs:

```rust
fn main() -> eframe::Result {
    let viewport = egui::ViewportBuilder::default()
        .with_app_id(APP_ID)
        .with_title("Vier")
        .with_inner_size([520.0, 640.0])
        .with_min_inner_size([320.0, 420.0]);
    let options = eframe::NativeOptions {
        viewport,
        ..Default::default()
    };
    eframe::run_native(
        "Vier",
        options,
        Box::new(|creation| Ok(Box::new(Vier::new(&creation.egui_ctx)))),
    )
}
```

The first half describes the window: its title and its size. The last line is
the one that matters. `eframe::run_native` opens the window and runs the event
loop, and it doesn't return until the window closes. Everything after this
happens because eframe calls into the program.

Its last argument is a closure, the small nameless function from chapter 5.
eframe calls it once, when the window is ready, and it makes a `Vier`, the
value that holds the program's state from then on. `Box::new` is how Rust
hands eframe a value to keep for as long as it runs; read past it. In
chapter 4's terms, this line is the host loading your file and calling
`fresh()`.

## 6.2 What the host asks for

How does eframe know what to call? Further down main.rs:

```rust
impl eframe::App for Vier {
    fn ui(&mut self, ui: &mut egui::Ui, _frame: &mut eframe::Frame) {
        ...
    }
}
```

`eframe::App` is a *trait*: a set of methods a type promises to have. It's
the same idea as Go's interface from chapter 2, a name for every type that can
do certain things. eframe will run any value whose type has the `App` trait,
and `impl eframe::App for Vier` is where `Vier` keeps the promise, by writing
the method the trait asks for. Here that's `ui`, which eframe calls on every
frame.

A trait is how a framework writes down its side of the deal. In chapter 4, the
host expected `fresh`, `clicked`, `tick` and `draw`, and nothing checked that
you'd written them. Here, if `Vier` didn't have a `ui` method, the program
wouldn't build.

## 6.3 One frame

Here is all of `ui`:

```rust
fn ui(&mut self, ui: &mut egui::Ui, _frame: &mut eframe::Frame) {
    let now = ui.input(|input| input.time);
    self.game.advance(now);
    if ui.input(|input| input.viewport().close_requested()) {
        self.game.save();
    }
    egui::CentralPanel::default().show(ui, |ui| match self.screen {
        Screen::Home => self.home(ui, now),
        Screen::Playing => self.playing(ui, now),
    });
    if let Some(deadline) = self.game.next_deadline() {
        ui.ctx()
            .request_repaint_after_secs((deadline - now).max(0.0) as f32);
    }
}
```

Put it next to chapter 4's host loop and the lines match up. First it gets
`now`, the time in seconds, from eframe, because the game has no clock of its
own. Then `self.game.advance(now)` is chapter 4's `tick`: it lets the game
catch up on anything whose time has come. If the window is closing, the game
saves. Then it draws whichever screen you're on, home or playing, which is
chapter 4's `draw`, and as you'll see in section 6.6, drawing is also where
clicks come in.

The last three lines are the part chapter 4 mentioned at the end. eframe
doesn't draw at a steady rate. It draws a frame when something happens, like a
click or the mouse moving, and otherwise it waits. That saves work, but it
means that if the computer's move is due in 0.4 seconds and you don't touch
the mouse, there might not be another frame to notice. So `ui` asks the game
when its next step is due and asks eframe to draw another frame by then.

## 6.4 The game

The game is in game.rs, and its state is a struct. Here are the fields this
chapter needs:

```rust
pub struct Game {
    board: Board,
    turn: Player,
    phase: Phase,
    last_drop: Option<(Position, f64)>,
    computer_column: Option<usize>,
    pending: Option<(f64, Step)>,
    ...
}
```

`board` and `turn` are chapter 1's. `phase` is chapter 4's idea, with one more
case:

```rust
pub enum Phase {
    PlayerTurn,
    AnimatingDrop,
    ComputerThinking,
    Finished(Outcome),
}
```

`AnimatingDrop` is the time a disc spends falling. Chapter 4's discs appeared
at once; vier-desktop's take a moment, and while they fall, the game doesn't
accept a click.

`(f64, Step)` is a *tuple*: two values held together without a struct to name
them. `f64` is Rust's `float`. So `pending` is either `None`, nothing
scheduled, or `Some` of a time and a step to take at that time. The steps are
another enum:

```rust
enum Step {
    FinishDrop,
    RevealComputerColumn(usize),
    ComputerDrop(usize),
}
```

In chapter 4, `computerThinking(column, dueAt)` held both what the game was
doing and what it was waiting for. vier-desktop splits those apart. `phase`
says what the screen should show: your turn, a disc falling, the computer
thinking, or the end. `pending` says what happens next and when. There are
three kinds of next thing: a falling disc lands, the computer's disc moves
over the column it chose, and the computer's disc drops.

`last_drop` remembers which disc fell most recently and when, which is how the
screen knows where to draw a falling disc. `computer_column` is where the
computer's disc hovers before it drops.

## 6.5 Catching up

`advance` is called on every frame:

```rust
pub fn advance(&mut self, now: f64) {
    while let Some((at, step)) = self.pending {
        if at > now {
            return;
        }
        self.pending = None;
        match step {
            Step::FinishDrop => self.finish_drop(at),
            Step::RevealComputerColumn(column) => {
                self.computer_column = Some(column);
                self.pending = Some((at + HOVER_SECONDS, Step::ComputerDrop(column)));
            }
            Step::ComputerDrop(column) => {
                self.computer_column = None;
                self.drop(column, at);
            }
        }
    }
}
```

`while let` is a loop that keeps going as long as the value matches the
pattern. Read it as: while there's a pending step, take it apart into `at` and
`step`. If the step isn't due yet, return; this is chapter 4's
`if now < dueAt { return game }`. If it is due, clear it and take it, with a
`match` on which step it is. Taking a step often schedules the next one.

Why a loop, when chapter 4's `tick` took at most one step? Because frames
don't come at a steady rate. If nothing drew a frame for a second, two or
three steps might be overdue at once, and the loop takes them all, in order,
before the screen is drawn. Notice too that each step is given `at`, the time
it was due, not `now`, the time it happened to get noticed. The next step is
scheduled from when this one should have happened, so a late frame doesn't
make everything after it late too.

## 6.6 One click, all the way through

Now follow a click. You're Red, it's your turn, and you click column 4.

The click arrives while drawing. The playing screen draws the board with
`board_view::show`, and that function hands back what the mouse did:

```rust
let board_area = ui.allocate_ui(Vec2::new(ui.available_width(), board_height), |ui| {
    board_view::show(ui, &self.game, now)
});
let input = board_area.inner;
if let Some(column) = input.hovered_column {
    self.game.select(column);
}
if let Some(column) = input.clicked_column {
    self.game.play(column, now);
}
```

`board_view::show` takes `&self.game`, a reference it can only look through,
so drawing can't change the game. It reports which column the mouse is over
and which was clicked, and the program passes the click to the game: chapter
4's `clicked(game, column, now)`, as `self.game.play(3, now)`.

`play` checks, as `clicked` did, that it's your turn and the column is open,
and then drops the disc:

```rust
fn drop(&mut self, column: usize, now: f64) {
    let Some(position) = self.board.drop(self.turn, column) else {
        return;
    };
    self.last_drop = Some((position, now));
    self.phase = Phase::AnimatingDrop;
    self.pending = Some((now + DROP_SECONDS, Step::FinishDrop));
}
```

The disc is in the board right away; `board.drop` is chapter 5's method. What
waits is everything after it. The phase becomes `AnimatingDrop`, and the disc
will land in `DROP_SECONDS`, 0.3 of a second. `play` returns, `ui` returns,
and eframe draws the frame.

From here, nothing happens because of you. Each frame, `advance` checks the
clock, and the steps go off one after another. Counting from the click:

| Time | Step | What you see |
|---|---|---|
| 0.0 | your click: `drop` | your disc starts to fall |
| 0.3 | `FinishDrop` | it lands; the computer starts thinking |
| 0.7 | `RevealComputerColumn` | the yellow disc slides over its column |
| 0.95 | `ComputerDrop` | the yellow disc starts to fall |
| 1.25 | `FinishDrop` | it lands; your turn |

`FinishDrop` is `finish_drop`, which is chapter 1's end-of-move check. It asks
the board for an outcome, and if there is one, the phase becomes `Finished`.
If not, the turn passes to the opponent and `begin_turn` starts the next one.
For a person, that means the phase becomes `PlayerTurn`. For the computer,
it calls `play_computer_turn`:

```rust
fn play_computer_turn(&mut self, now: f64) {
    self.phase = Phase::ComputerThinking;
    self.computer_column = Some(self.selected_column);
    let column = engine::best_move(&self.board, self.turn, self.difficulty, &mut self.rng);
    self.pending = Some((now + THINKING_SECONDS, Step::RevealComputerColumn(column)));
}
```

The computer picks its column right away, with `best_move` from chapter 5,
which takes a tiny fraction of a second. The thinking you see on the screen is
a pause the program adds afterwards, so the computer's move doesn't appear the
same instant yours lands. Its disc first waits over your column, then
`RevealComputerColumn` moves it over the chosen column, and `ComputerDrop`
drops it with the same `drop` your click used.

That's the route: `ui` → `board_view::show` reports the click →
`Game::play` → `drop` → frames go by → `advance` takes `FinishDrop`,
`RevealComputerColumn`, `ComputerDrop` and `FinishDrop` as each comes due. Put
it next to vier-cli's route from chapter 3. Every call in vier-cli happened in
one go, inside `play`. Here the same steps are spread over a second and a
quarter, and between them the program goes back to the host.

## 6.7 Drawing from the game, every frame

`board_view::show` draws the whole board, every frame: the blue frame, every
disc in it, and the disc hovering over the top. It keeps nothing from the frame
before. egui, the library eframe draws with, calls this *immediate mode*: you
don't create a board on the screen and then update it, you describe the whole
screen again each time, and egui draws what you described. It's chapter 4's
`draw`, which built the screen fresh from the game every time it was called.

Immediate mode is why the falling disc needs no special machinery. Here's the
part of `show` that works out how far a disc has fallen:

```rust
if let Some((dropped, at)) = game.last_drop()
    && dropped == position
{
    let progress = (((now - at) as f32) / FALL_SECONDS).clamp(0.0, 1.0);
    ...
    y = field_row * progress * progress;
}
```

If this disc is the one that dropped last, `progress` is how much of the fall
time has passed, from 0 to 1, and the disc is drawn that far down. Each frame,
`now` is a little later, so the disc is drawn a little lower, and it looks as if
it's falling. Nothing moves the disc. It's drawn from the game and the time,
like everything else.

The view also reports instead of acting. It doesn't decide whether a click
counts; it says which column was clicked and leaves the deciding to `play`.
That's why a click while a disc is falling does nothing: the view reports it,
and `play` sees the phase isn't `PlayerTurn` and ignores it, the way
`clicked` did in chapter 4. One of the tests from chapter 5 checks it: `input_is_ignored_while_a_disc_falls`.

## 6.8 Remembering

`finish_drop` calls `save` after every move, and `save` writes a `SavedGame`:

```rust
#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
struct SavedGame {
    board: Board,
    turn: Player,
    starter: Player,
    difficulty: Difficulty,
    mode: Mode,
}
```

The work of turning this into JSON is in the `derive` line. `Serialize` and
`Deserialize` are serde's, and they write the code that converts a value to
text and back, for this struct and, because `Board` and `Player` derive them
too, for everything inside it. vier-cli's memory.go spelled out how a board
becomes six lines of letters; vier-desktop lets serde decide, and a saved board
comes out as rows of `"red"`, `"yellow"` and `null`. The file is
`~/.local/state/vier/state.json` on Linux and a Mac, and
`%LOCALAPPDATA%\vier\state.json` on Windows.

The game also saves when the window is closing, which you saw in `ui`. If you
close the window while a disc is still falling, the disc is already in the
board but `finish_drop` hasn't run to save it, and the save on closing catches
it. vier-cli never needed that, because each of its moves finished before it
read another line. Under a host, closing the window is one more event, and the
program hears about it on a frame like any other.

## 6.9 What you found

| Piece | lux | vier-desktop |
|---|---|---|
| The board | `Board` | `Board` in board.rs |
| The rules | `canDrop`, `dropped`, `winner`, `isFull` | `can_drop`, `drop`, `winner`, `outcome` in board.rs |
| The turn | `turn` and `done` | `turn`, `phase` and `pending` in game.rs |
| The loop | `while !done` | eframe's, calling `ui` each frame, with `advance` taking steps as they come due |
| The display | `show` | `board_view::show`, redrawing everything from the game and the time |

You've now read two real programs built around the same five pieces, one that
runs its own loop and one that's run by a host. The new Rust ideas in this
chapter were few: a trait is a promise a type makes, a tuple holds values
together without a name, `while let` loops while a pattern matches, and
immediate mode draws the whole screen every frame. The rest was chapter 4.

The last app takes the idea one step further. In vier-desktop, the program
still draws every frame itself, even if it draws the same thing as last time.
In vier-ios, written in Swift with SwiftUI, you describe what the screen should
look like for a given state of the game, and SwiftUI works out when to draw it
again: whenever the game changes. Chapter 7 opens it.
