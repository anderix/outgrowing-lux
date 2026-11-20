# Preface

This book starts where lux leaves you. You can write a program in lux, it runs,
and it does what you meant. The next step is reading programs written in the
languages lux was built to lead to: real programs, written by someone else,
much bigger than anything you've written yourself.

That sounds harder than it is. A real program is made of the same pieces as
yours. It has data, functions that change the data, a loop, and a way of
talking to the person using it. What's different is the spelling, the size, and
a few ideas lux never needed. If you know what a program does before you open
it, you can find those pieces in the code, and once you've found them, you
understand the program, even if there are lines in it you couldn't write
yourself.

## The example

The book follows one game. Vier is four in a row: two players take turns
dropping discs into a board seven columns wide and six rows tall, and the first
to line up four across, down or diagonally wins.

Chapter 1 writes Vier in lux, and that program is your map for the rest of the
book. The chapters after it read three real versions of the same game: vier-cli,
written in Go, which plays in a terminal; vier-desktop, written in Rust, which
plays in a window on a computer; and vier-ios, written in Swift, which plays on
an iPhone and an Apple Watch. All three play against the computer as well as against a friend, and all three
are programs people use. In each one, you find the pieces you wrote in chapter
1, learn the one or two new ideas that program depends on, and build it and run
it yourself.

## What you need

You need to know lux: structs, enums, `match`, `Option`, arrays and functions.
If you need a refresher, run `lux learn`. You don't need to know Go, Rust or
Swift. The book explains what you need from each when you get there.

To build the apps you need lux from [anderix.com/lux](/lux/), Go from
[go.dev](https://go.dev/dl/), and Rust from [rustup.rs](https://rustup.rs). The
iPhone and Watch app needs a Mac with Xcode. Without one, you can still read
that part; you just can't run the app.

## The code

Chapter 1's program is in the [book's repository](https://github.com/anderix/outgrowing-lux),
under `examples/ch01-lux`:

```text
cd examples/ch01-lux
lux run vier.lux
```

The three apps each have their own repository, and each part of the book says
where to find it.
