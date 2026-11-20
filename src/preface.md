# Preface

This book starts where lux leaves you. You can write a program in lux, it runs,
and it does what you meant. The next question is what it takes to turn that
program into something other people install and use. The answer runs through
another language, because lux was built to be outgrown, and through a lot of
work that isn't about any language at all: deciding what to build next, testing
what you built, saving what the player was doing, and packaging the program so
someone can install it with one command.

## The example

The book builds one game the whole way through. Vier is four in a row: two
players take turns dropping discs into a board seven columns wide and six rows
tall, and the first to line up four across, down or diagonally wins. Vier
already exists as an iPhone and Apple Watch app and as a Linux desktop app. This
book builds a third version, `vier-cli`, which plays in a terminal against a
friend or against the computer.

Chapter 1 writes the game in lux. Chapter 2 turns it into Go, first with
`lux convert` and then by hand. The chapters after that grow the Go program one
piece at a time until it plays against the computer, remembers an unfinished
game, takes options on the command line, and ships. The program at the end is
the version people install; its source is at
[github.com/anderix/vier-cli](https://github.com/anderix/vier-cli).

## What you need

You need to know lux: structs, enums, `match`, `Option`, arrays and functions.
If you need a refresher, run `lux learn`. You don't need to know Go yet. The
book explains each piece of Go the first time the program uses it, and
[Programming in Go](/go/) covers the language in more depth
when you want it.

Install lux from [anderix.com/lux](/lux/) and Go from
[go.dev](https://go.dev/dl/).

## Running the code

The program at each stage lives under `examples/` in the
[book's repository](https://github.com/anderix/outgrowing-lux), one folder per
chapter. Chapter 1's folder holds a lux file:

```text
cd examples/ch01-lux
lux run vier.lux
```

Every folder after it is a complete Go program with its tests:

```text
cd examples/ch02-runs
go run .
go test
```

Each folder is the real program at that point in its history, copied from the
commit that built it. Type your own version alongside if you want to; that is
the best way to read this. If yours stops working, compare it with the next
folder.
