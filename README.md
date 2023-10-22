# Flip: A CLI Application Framework for V

**Flip** is a simple library designed to help you with the creation of command-line interface (CLI) applications in the V programming language. It simplifies the process of building CLI applications by providing a set of utilities for defining commands, flags, and subcommands.

## Why Flip?

Flip was created as a result of a simple misunderstanding. The author initially set out to build their own CLI application framework to avoid a specific feature in the `cli` library, only to later discover that it could be easily disabled. Nonetheless, the experience of developing Flip turned out to be a great way to learn V, and it provides a great alternative for building CLI tools.

## Table Of Contents

- [Examples](#examples)
	- [A Simple Echo Command](#a-simple-echo-command)
	- [Getting Flags](#getting-flags)
- [Getting Started](#getting-started)
- [Contributing](#contributing)

## Examples

Here are some exaples of how to use Flip to create CLI apps.

### A Simple Echo Command

This example shows how to create a basic "echo" command using Flip:

```v
module main

import os
import flip

fn main() {
	mut app := &flip.Flip{
		name: 'echo'
		description: 'A simple echo command.'
		execute: fn (f flip.Flip) ! {
			println(f.args()!.join(' '))
		}
	}
	app.init(os.args[1..])
	app.parse()!
}
```

### Getting Flags

In this example, we define a CLI application that can accept various flags:

```v
module main

import os
import flip

fn main() {
	mut app := &flip.Flip{
		name: 'test'
		execute: fn (f flip.Flip) ! {
			for flag in f.flags {
                println(flag)
            }
			println('\nThe value of "text" is "${f.flags()['text']}"')
		}
	}
	app.init(os.args)
    app.bool('checkerboard', false, 'Show table as a checkerboard')
    app.string('text', 'default value', 'Some string')
    app.float('floating-point', .0, 'Some float')
    app.int('integer', 0, 'Some integer')
	app.parse()!
}
```

This is what it will output:

```bash
$ v run . -checkerboard -text 'I like waffles'
checkerboard: "true"
text: "I like waffles"
floating-point: "0.0"
integer: "0"

The value of "text" is "I like waffles"
```

## Getting Started

To begin using Flip in your projects, you can follow these steps:

1. Install Flip as a module in your V project:
	```bash
	v install https://github.com/katekyy/flip
	```

2. Import Flip in your code:
	```v
	import flip
	```

3. Define your CLI application using Flip's functionality.

4. Initialize and parse command-line arguments as shown in the examples.

## Contributing

We welcome contributions from the community! If you find issues or have ideas for enhancements, please create an issue or submit a pull request.

---

MIT © 2023 katekyy

