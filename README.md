# Flip: A CLI Application Library for V

**Flip** is a simple library designed to help you with the creation of command-line interface (CLI) applications in the V programming language. It simplifies the process of building CLI applications by providing a set of utilities for defining commands and flags.

## Why Flip?

Flip was created as a result of a simple misunderstanding. The author initially set out to build their own CLI application framework to avoid a specific feature in the `cli` library, only to later discover that it could be easily disabled. Nonetheless, the experience of developing Flip turned out to be a great way to learn V, and it provides a great alternative for building CLI tools.

## Table Of Contents

- [Flip: A CLI Application Library for V](#flip-a-cli-application-library-for-v)
	- [Why Flip?](#why-flip)
	- [Table Of Contents](#table-of-contents)
	- [Examples](#examples)
		- [A Simple Echo Command](#a-simple-echo-command)
		- [Getting Flags](#getting-flags)
		- [Runtime flag type checking](#runtime-flag-type-checking)
		- [Custom error handler](#custom-error-handler)
	- [More examples](#more-examples)
	- [Getting Started](#getting-started)
	- [Contributing](#contributing)

## Examples

Here are some exaples of how to use Flip to create CLI apps.

### A Simple Echo Command

This example shows how to create a basic "echo" command using Flip:

```v
mut app := flip.new_app(
	description: 'A simple echo command.'
	execute: fn (args []string, _ flip.Flip) ! {
		println(args.join(' '))
	}
	force_skip_cmds: true
	disable_help: true
)
app.init(os.args)
app.parse()!
```

`force_skip_cmds` field tells Flip to ignore parsing arguments to find the next command after this one.
Since it's the root of our app, it'll print out a note saying that the app will skip every declared command.
But, since we don't have any commands declared (no help whatsoever), we don't need to worry about it.
If we would tho. We would need to run the code with `v -d skip_cmds run .` to stop printing that message.

### Getting Flags

In this example, we define a CLI application that can accept various flags:

```v
mut app := flip.new_app(
	execute: fn (f flip.Flip, _ []string) ! {
		if f.get_bool('checkerboard') {
			return error('unimplemented')
		}
		println(f.get_string('text'))
	}
)
app.init(os.args)
app.bool('checkerboard', none, 'Flag description')
app.string('text', none, 'Some string')
app.float('floating-point', `f`, 'Some float')
app.int('integer', none, 'Some integer')
app.parse()!
```

This is what it will output if we set the "checkerboard" flag:

```console
$ v run . -checkerboard
error: unimplemented
run test help for usage
```

### Runtime flag type checking

Like in previous example, we created a new CLI app.
Now, what happens if we call `get_string('checkerboard')`?
It'll panic because the original type was not string, but bool.

```v
mut app := flip.new_app(
	execute: fn (f flip.Flip, _ []string) ! {
		println(f.get_string('checkerboard'))
	}
)
app.init(os.args)
app.bool('checkerboard', none, 'Flag description')
app.parse()!
```

```console
$ v run . -checkerboard
V panic: type of flag checkerboard is bool, not string, therefore it cannot be obtained
```

### Custom error handler

In the root command (created with `new_app(...)`) you can declare your own error handler.

```v
mut app := flip.new_app(
	execute: fn (f flip.Flip, _ []string) ! {
		return error('unimplemented')
	}
	error_handler: fn (_ flip.Flip, e IError) ! {
		eprintln('unexpected error: ${e.msg()}')
	}
)
app.init(os.args)
app.parse()!
```

## More examples

You can find more examples in [examples](examples/).

## Getting Started

To begin using Flip in your projects, you can follow these steps:

1. Install Flip in your V project:
	```bash
	v install https://github.com/katekyy/flip
	```

2. Import Flip into your code:
	```v
	import flip
	```

3. Define your CLI application using Flip's functionality.

4. Initialize and parse command-line arguments as shown in the examples.

## Contributing

If you find issues or have ideas for enhancements, please create an issue or submit a pull request.

---

MIT © 2023 katekyy
