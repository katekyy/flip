module flip

import math { max }
import term
import strings { repeat_string }

type FnX = fn (Flip) !

type FnE = fn (Flip, IError) !

pub struct Padding {
pub:
	left   int
	right  int
	top    int
	bottom int
}

pub struct Flip {
pub mut:
	commands   []Flip
	categories map[string]string
	category   string
pub:
	name          string
	alias         []string
	usage         string
	description   string
	takes_args    bool
	execute       FnX = unsafe { nil }
	error_handler FnE = fn (f Flip, err IError) ! {
		eprintln(term.bg_red('Error:') + ' ' + err.msg())
		f.print_help()
		exit(err.code())
	}

	help_padding Padding = Padding{
		left: 2
		right: 10
	}
mut:
	args               []string // Use `args()` to get this field.
	invoked            bool
	flags              []Flag // Use flags() to get this field.
	flag_parser        &FlagParser = unsafe { nil }
	mapped_flags       map[string]string
	help__max_name_len int
	help__initialized  bool
}

// init initializes the given flip with a default help command and passes the args to the flip.
// Note: If you don't want a help command then you can call `init_no_help()` function instead.
pub fn (mut f Flip) init(args []string) {
	f.impl_init(args, false, 0)
	f.flag_parser = FlagParser.new(args)
	f.help__initialized = true
	f.commands << &Flip{
		name: 'help'
		description: 'Show help for this application.'
		category: 'misc'
		takes_args: true
		execute: fn (f Flip) ! {
			f.help_helper(0)
		}
	}
}

fn (mut f Flip) impl_init(args []string, command bool, i int) {
	f.args = args
	if command {
		f.args = args[args.len % i..]
	}
	if f.categories['misc'] == '' {
		f.categories['misc'] = 'Miscellaneous'
	}
	for mut sub in f.commands {
		if sub.category == '' {
			sub.category = 'misc'
		}
		sub.impl_init(f.args, true, i + 1)
	}
}

fn (f Flip) help_helper(prec int) {
	if prec + 1 <= f.args.len {
		next_flip := f.get_sub(f.args[prec]) or {
			f.print_help()
			return
		}

		next_flip.help_helper(prec + 1)
	} else {
		f.print_help()
	}
}

// init_no_help initializes the given flip with `args`.
pub fn (mut f Flip) init_no_help(args []string) {
	f.impl_init(args, false, 1)
}

// print_help prints help for the flip
pub fn (f Flip) print_help() {
	mut buf := ''
	if !f.description.is_blank() {
		buf += '${f.description}\n\n'
	}
	buf += 'Usage: ${f.name}'
	if f.usage.is_blank() {
		cmd := if f.help__initialized { 1 } else { 0 }
		if f.visible_flags_count() > 0 {
			buf += ' [flags]'
		}
		if f.commands.len > cmd {
			buf += ' [command]'
		}
		if f.takes_args {
			buf += ' [arguments] ...'
		}
	}
	if !f.usage.is_blank() {
		usg := 'Usage: '
		buf += ' ' + f.usage.split('\n').join('\n${get_spaces(usg.len)}')
	}
	buf += '\n\n'
	print(buf)
	f.print_commands()
	f.print_flags()
}

fn (f Flip) visible_flags_count() int {
	mut i := 0
	for flag in f.flags {
		if flag.private && f.name !in flag.private_for {
			continue
		}
		i++
	}
	return i
}

fn (mut f Flip) move_flags() {
	for mut sub in f.commands {
		sub.flags = f.flags
	}
	f.flag_parser = unsafe { nil }
}

// parse parses the commands from flip.args and then executes the first one that it encounters.
// Note: The left arguments are reserved for commands and can be accessed inside of it.
pub fn (mut f Flip) parse() ! {
	f.flag_parser.join_arrays()
	f.move_fields()
	f.move_flags()
	f.flags_to_map()
	f.set_max_length()
	for mut sub in f.commands {
		sub.set_max_length()
	}
	f.exec_commands() or {
		if err.msg() != '!' {
			f.error_handler(f, err)!
			return
		}
		if !f.invoked && isnil(f.execute) {
			f.print_help()
			return
		}
		if isnil(f.execute) {
			return
		}
		f.execute(f) or {
			if !isnil(f.error_handler) {
				f.error_handler(f, err)!
				return
			}
			eprintln(err)
			exit(err.code())
			return
		}
	}
}

fn (mut f Flip) exec_commands() !string {
	args := f.args
	for arg in args {
		for mut sub in f.commands {
			if sub.name == arg || arg in sub.alias {
				f.invoked = true
				sub.exec_commands() or {
					f.rem_arg(arg)
					if isnil(sub.execute) {
						return error('The `execute` field is nil!\nGiven command is not implemented yet. Or it is broken!')
					}
					sub.execute(f) or {
						sub.error_handler(sub, err)!
						return err
					}
					return arg
				}
			}
		}
	}
	return error('!')
}

// exec_command executes a command thats name is `name`.
// Note: You can also run nested commands with this syntax: `sub1:sub2:sub3`
pub fn (f Flip) exec_command(name string) ! {
	names := name.split(':')
	is_nested := names.len > 1
	for sub in f.commands {
		if sub.name == names[0] {
			if is_nested {
				sub.exec_command(names[names.len - 1..].join(':'))!
			}
			if isnil(sub.execute) {
				return error('The `execute` field is nil!\nGiven command is not implemented yet. Or it is broken!')
			}
			sub.execute(f)!
			return
		}
	}
	return error('Could not find command "${names[0]}".')
}

fn (mut f Flip) rem_arg(s string) {
	mut buf := []string{}
	for arg in f.args {
		if arg != s {
			buf << arg
		}
	}
	f.args = buf
}

// add_global_category adds a category for all commands defined in the flip
pub fn (mut f Flip) add_global_category(key string, title string) {
	f.categories[key] = title
	for mut sub in f.commands {
		sub.add_global_category(key, title)
	}
}

// set_global_category adds an already existing category for all commands defined in the flip
pub fn (mut f Flip) set_global_category(key string) {
	title := f.categories[key]
	for mut sub in f.commands {
		sub.categories[key] = title
		sub.set_global_category(key)
	}
}

fn (mut f Flip) flags_to_map() {
	mut mapped_flags := map[string]string{}
	for flag in f.flags {
		mapped_flags[flag.label] = flag.value
	}
	f.mapped_flags = mapped_flags.move()
}

// args returns a list of arguments with length greater than 0
pub fn (f Flip) args() ![]string {
	if f.args.len < 1 {
		return error('Too few arguments!')
	}
	return f.args
}

// flags returns a map of all flags
pub fn (f Flip) flags_map() map[string]string {
	return f.mapped_flags
}

pub fn (f Flip) flags() []Flag {
	return f.flags
}

fn (f Flip) print_flags() {
	mut buf := ''
	if f.visible_flags_count() != 0 {
		buf += 'Flags:\n'
		for flag in f.flags {
			if flag.private && f.name !in flag.private_for {
				continue
			}
			buf += flag.parse_info(f) + '\n'
		}
		buf += '\n'
	}
	print(buf)
}

fn (f Flip) print_commands() {
	mut buf := ''
	subs := f.commands

	mut sub_names := []string{}
	for sub in subs {
		sub_names << sub.name
	}

	mut ss := map[string][]string{}

	for sub in subs {
		ss[sub.category] << sub.parse_info(f)
	}

	for cat, title in f.categories {
		if !f.commands.category_used(cat) {
			continue
		}

		buf += '* ${title}:\n'
		for s in ss[cat] {
			buf += '${s}\n'
		}
		buf += '\n'
	}
	print(buf)
}

fn (flag Flag) parse_info(f Flip) string {
	padding := f.help_padding
	mut str := '${get_spaces(padding.left)}-${flag.label}'

	usage := flag.description.split('\n')
	for i, line in usage {
		if i != 0 {
			str += '\n${get_spaces(padding.left + flag.label.len +
				f.help__max_name_len - flag.label.len + padding.right)}${line}'
			continue
		}
		str += '${get_spaces(f.help__max_name_len - flag.label.len + padding.right - 1)}${line}'
	}

	return str
}

fn (sub Flip) parse_info(f Flip) string {
	padding := f.help_padding
	label := if sub.alias.len > 0 { sub.name + ', ' + sub.alias.join(', ') } else { sub.name }
	mut label_len := label.len

	mut str := '${get_spaces(padding.left)}${label}'
	if sub.takes_args {
		str = '${get_spaces(padding.left)}${label} ...'
		label_len += 4
	}

	desc := sub.description.split('\n')
	for i, line in desc {
		if i != 0 {
			str += '\n${get_spaces(padding.left + f.help__max_name_len + padding.right)}${line}'
			continue
		}
		str += '${get_spaces(f.help__max_name_len - label_len + padding.right)}${line}'
	}
	return str
}

fn (flips []Flip) category_used(s string) bool {
	for f in flips {
		if f.category == s {
			return true
		}
	}
	return false
}

fn (f Flip) get_sub_names() []string {
	mut buf := []string{}
	for sub in f.commands {
		buf << sub.name
	}
	return buf
}

fn (f Flip) get_sub(name string) ?Flip {
	for sub in f.commands {
		if sub.name == name || name in sub.alias {
			return sub
		}
	}
	return none
}

fn (mut f Flip) set_max_length() {
	mut flag_names := []string{}
	mut sub_names := []string{}

	flags := f.flags
	subs := f.commands

	for flag in flags {
		flag_names << flag.label
	}

	for sub in subs {
		if sub.takes_args {
			sub_names << '${sub.name} ...'
			continue
		}
		if sub.alias.len > 0 {
			sub_names << sub.name + ', ' + sub.alias.join(', ')
			continue
		}
		sub_names << sub.name
	}

	a := get_max_length(flag_names)
	b := get_max_length(sub_names)

	f.help__max_name_len = max(a, b)
}

fn get_max_length(ss []string) int {
	mut lens := []int{}

	for s in ss {
		lens << s.len
	}

	return max_from_array(lens, 0)
}

fn max_from_array(i []int, j int) int {
	mut big := j
	for x in i {
		if x > big {
			big = x
		}
	}
	return big
}

fn get_spaces(i int) string {
	return repeat_string(' ', i)
}
