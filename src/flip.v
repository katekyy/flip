module flip

import term
import os

// V fmt is weird? error: parameter name must not begin with upper case letter (`IError`)
// pub type FlipFunction     = fn (Flip, []string) !
// pub type FlipErrorHandler = fn (Flip, IError) !

@[heap; params]
pub struct Flip {
	docs    Docs
	is_root bool
mut:
	categories  map[string]string
	parent      &Flip = unsafe { nil }
	args        []string
	flag_parser &FlagParser = new_flag_parser()
pub:
	execute       fn (Flip, []string) ! = unsafe { nil }
	error_handler fn (Flip, IError) !   = fn (f Flip, e IError) ! {
		eprintln(term.bold(term.red('error:')) + ' ${e.msg()}')
		eprintln('run ' + term.bold(f.name + ' help') + ' for usage')
		exit(1)
	}
	// If true, copies arguments including the first element
	include_prog_name bool
	// Removes the default help command
	disable_help bool
	// Doesn't look for flags in the args
	disable_flags bool
	// If next command was not found, runs the current one with arguments as the unknown command path
	no_unknown_cmds bool
	// Skips searching for the next command in the command path (arguments)
	force_skip_cmds bool
	// Show in help that the command takes options
	takes_flags bool
	// Set custom usage in help
	custom_usage ?string
pub mut:
	name        string
	category    string
	description string
	commands    []&Flip
}

// new_app returns a new app
pub fn new_app(opts Flip) &Flip {
	return &Flip{
		...opts
		is_root: true
	}
}

// new_command returns a new command
pub fn new_command(opts Flip) &Flip {
	if opts.name.is_blank() {
		panic('name of a command cannot be blank')
	}
	return &Flip{
		...opts
	}
}

// init initializes the app created with `new_app`
pub fn (mut f Flip) init(args []string) {
	if !f.is_root {
		panic('you cannot initialize a command (Flip.init() called on a non root Flip)')
	}
	if args.len < 1 {
		return
	}
	if f.name.is_blank() {
		f.name = os.file_name(args[0]).all_before_last('.')
		if f.name.len < 1 {
			panic('please specify the app name')
		}
	}
	f.args = if f.include_prog_name { args } else { args[1..] }
	if !f.disable_help {
		f.commands << new_command(
			name: 'help'
			description: 'Show help for this application.'
			force_skip_cmds: true
			execute: fn (f Flip, args []string) ! {
				f.find_command(args[1..])!.show_help()
			}
		)
	}
	f.connect_children_to_parent()
}

fn (mut f Flip) connect_children_to_parent() {
	for mut child in f.commands {
		child.parent = f
		child.connect_children_to_parent()
	}
}

// parse parses the arguments passed to the app by `init`
pub fn (mut f Flip) parse() ! {
	if f.flag_parser.flags.len > 0 {
		if f.disable_flags {
			panic('flags were disabled but you declared some')
		}
		f.flag_parser.parse(f.args) or { return f.error_handler_safe(err) }
	}
	mut i := 0
	for flag in f.flag_parser.flags {
		if flag.idx < 0 {
			continue
		}
		mut count := 1
		if flag.val_idx >= 0 {
			count++
		}
		f.args.delete_many(flag.idx - i, count)
		i += count
	}
	mut cmd := &Flip{}
	if !f.force_skip_cmds {
		cmd = f.find_command(f.args) or { return f.error_handler_safe(err) }
	} else {
		$if !skip_cmds ? {
			if f.commands.len > 0 {
				eprintln(term.bold('note:') +
					' by skipping next commands the user will not be able to call commands.\n${' ':6}Set `-d skip_cmds` if you do not want this message.\n')
			}
		}
		cmd = f
	}
	if isnil(cmd.execute) {
		if !cmd.is_root {
			panic('command ${cmd.name} is unimplemented')
		}
		f.show_help()
		return
	}
	cmd.execute(f, f.args) or { return f.error_handler_safe(err) }
}

// find_command walks through commands in the path and returns a reference to the last one.
// If the currently walked command is not valid (doesn't exist), it returns an error
pub fn (f Flip) find_command(path []string) !&Flip {
	if path.len <= 0 {
		return f
	}
	for cmd in f.commands {
		if cmd.name != path[0] {
			continue
		}
		if cmd.force_skip_cmds {
			return cmd
		}
		if path.len >= 1 {
			return cmd.find_command(path[1..])
		}
	}
	if f.no_unknown_cmds {
		return f
	}
	return error('unknown command `${path[0]}`')
}

fn (f Flip) help_helper(args []string, i int) &Flip {
	if args.len <= 0 {
		return f
	}
	for cmd in f.commands {
		if cmd.name != args[i] {
			continue
		}
		if args.len > i + 1 {
			return cmd.help_helper(args, i + 1)
		}
		return cmd
	}
	return unsafe { nil }
}

fn (f Flip) root() &Flip {
	if f.is_root || isnil(f.parent) {
		return f
	}
	return f.parent.root()
}

fn (f Flip) error_handler_safe(e IError) ! {
	if isnil(f.error_handler) {
		return e
	}
	f.error_handler(f, e)!
}

// set_help_category sets the category of the default help command
pub fn (mut f Flip) set_help_category(key string) {
	f.get_category(key)
	f.find_command(['help']) or { panic('help command not found, try caling this after init') }.category = key
}

// add_category adds a category to the app to show in help
pub fn (mut f Flip) add_category(key string, title string) {
	if key.len <= 0 {
		panic('category must have a non empty key')
	}
	f.categories[key] = title
}

fn (f Flip) get_category(key string) string {
	return f.categories[key] or { panic('unknown category with key ${key}') }
}
