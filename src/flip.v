module flip

import math { max }
import term { bold, red }

type FnX = fn (Flip) !

type FnE = fn (IError) !

struct Flag {
pub mut:
	label string
	value string
}

// str returns the string version of flag
pub fn (f Flag) str() string {
	return '${f.label}: "${f.value}"'
}

fn (fs []Flag) get_by_meta(fm FlagMeta) ?Flag {
	for f in fs {
		if f.label == fm.label {
			return f
		}
	}
	return none
}

fn (mut fms []FlagMeta) remove(fm FlagMeta) ?FlagMeta {
	mut flag_metas := []FlagMeta{}
	mut flag_meta := FlagMeta{}

	for glob in fms {
		if fm.label == glob.label {
			flag_meta = fm
			continue
		}

		flag_metas << glob
	}

	fms = flag_metas.clone()

	if flag_meta == FlagMeta{} {
		println(flag_meta)
		return none
	}
	return flag_meta
}

struct FlagMeta {
	label   string
	usage   string
	default string
}

pub struct Padding {
pub:
	left   int
	right  int
	top    int
	bottom int
}

pub struct Flip {
pub mut:
	subcommands []Flip
	categories  map[string]string
	category    string
	flags       []Flag // Use flags() to get this field.
pub:
	name          string
	alias         []string
	description   string
	takes_args    bool
	execute       FnX = unsafe { nil }
	error_handler FnE = unsafe { nil } // This is only invoked at the main Flip. Also, the subcommand errors are falling back into the main Flip.

	help_padding Padding = Padding{
		left: 2
		right: 10
	}
mut:
	args                  []string // Use `args()` to get this field.
	mapped_flags          map[string]string
	invoked__             bool
	flag_metas__          []FlagMeta
	max_name_len__        int
	initialized_with_help bool
}

// init initializes the given flip with a default help subcommand and passes the args to the flip.
// Note: If you don't want a help subcommand then you can call `init_no_help()` function instead.
pub fn (mut f Flip) init(args []string) {
	f.impl_init(args, false, 1)
	f.initialized_with_help = true
	f.subcommands << &Flip{
		name: 'help'
		description: 'Show help for this application.'
		category: 'misc'
		takes_args: false
		execute: fn (f Flip) ! {
			f.help_helper(0)
		}
	}
}

fn (f Flip) help_helper(prec int) {
	if prec < f.args.len {
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

fn (mut f Flip) impl_init(args []string, subcommand bool, i int) {
	f.args = args
	if subcommand {
		f.args = args[i % args.len..]
	}

	if f.categories['misc'] == '' {
		f.categories['misc'] = 'Miscellaneous'
	}
	for mut sub in f.subcommands {
		if sub.category == '' {
			sub.category = 'misc'
		}
		sub.impl_init(f.args, true, i + 1)
	}
}

// print_help prints help for the flip
pub fn (f Flip) print_help() {
	mut buf := ''
	if f.description != '' {
		buf += '${f.description}\n\n'
	}
	buf += 'Usage: ${f.name}'
	cmd := if f.initialized_with_help { 1 } else { 0 }
	if f.flag_metas__.len > 0 {
		buf += ' [flags]'
	}
	if f.subcommands.len > cmd {
		buf += ' [command]'
	}
	if f.takes_args {
		buf += ' [arguments] ...'
	}
	buf += '\n\n'

	print(buf)
	f.print_subcommands()
	f.print_flags()
}

fn (mut f Flip) clon_em() {
	for global_meta in f.flag_metas__ {
		usage := global_meta.usage.trim_space()
		mut names := []string{}

		if usage.len > 2 && usage[0].ascii_str() == '[' {
			mut buf := ''
			for i, character in usage[1..] {
				ch := character.ascii_str()
				if i - 1 == usage.len {
					return
				}
				match ch {
					']' { break }
					' ' { continue }
					',' { names << buf }
					else {}
				}
				println(ch)
				buf += ch
			}
		} else {
			return
		}

		for name in names {
			for mut sub in f.subcommands {
				if name == sub.name {
					sub.flag_metas__ << FlagMeta{
						label: global_meta.label
						usage: usage.split(']')[1].trim_space()
					}
					sub.flags << f.flags.get_by_meta(global_meta) or { Flag{} }
				}
			}
		}
		f.flag_metas__.remove(global_meta)
	}
}

// parse parses the subcommands from flip.args and then executes the first one that it encounters.
// Note: The left arguments are reserved for subcommands and can be accessed inside of it.
pub fn (mut f Flip) parse() ! {
	f.clon_em()
	f.flags_to_map()
	f.set_max_length()
	for mut sub in f.subcommands {
		sub.set_max_length()
	}

	f.exec_subcommands() or {
		if err.msg() != '!' {
			if isnil(f.error_handler) {
				eprintln(bold(red('Error: ')) + err.msg())
				return
			}
			f.error_handler(err)!
			return
		}

		if !f.invoked__ && isnil(f.execute) {
			f.print_help()
			return
		}

		if !isnil(f.execute) {
			f.execute(f)!
		}
	}
}

fn (mut f Flip) exec_subcommands() !string {
	args := f.args
	for arg in args {
		for mut sub in f.subcommands {
			if sub.name == arg || arg in sub.alias {
				f.invoked__ = true
				sub.exec_subcommands() or {
					if err.msg() != '!' {
						return err
					}
					f.rem_arg(arg)
					if isnil(sub.execute) {
						return error('The `execute` field is nil!\nGiven subcommand is not implemented yet. Or it is broken!')
					}
					sub.execute(f)!
					return arg
				}
			}
		}
	}
	return error('!')
}

// exec_subcommand executes a subcommand thats name is `name`.
// Note: You can also run nested subcommands with this syntax: `sub1:sub2:sub3`
pub fn (f Flip) exec_subcommand(name string) ! {
	names := name.split(':')
	is_nested := names.len > 1
	dump(names)
	for sub in f.subcommands {
		if sub.name == names[0] {
			if is_nested {
				sub.exec_subcommand(names[names.len - 1..].join(':'))!
			}
			if isnil(sub.execute) {
				return error('The `execute` field is nil!\nGiven subcommand is not implemented yet. Or it is broken!')
			}
			sub.execute(f)!
			return
		}
	}
	return error('Could not find subcommand "${names[0]}".')
}

// add_global_category adds a category for all subcommands defined in the flip
pub fn (mut f Flip) add_global_category(key string, title string) {
	f.categories[key] = title
	for mut sub in f.subcommands {
		sub.add_global_category(key, title)
	}
}

// set_global_category adds an already existing category for all subcommands defined in the flip
pub fn (mut f Flip) set_global_category(key string) {
	title := f.categories[key]
	for mut sub in f.subcommands {
		sub.categories[key] = title
		sub.set_global_category(key)
	}
}

fn (mut f Flip) flags_to_map() {
	mut mapped_flags := map[string]string{}
	for flag in f.flags {
		mapped_flags[flag.label] = flag.value
	}
	for flag_meta in f.flag_metas__ {
		if flag_meta.label !in mapped_flags {
			mapped_flags[flag_meta.label] = flag_meta.default
		}
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

// flags returns a map of flags that were passed and flags that were not
pub fn (f Flip) flags() map[string]string {
	return f.mapped_flags
}

fn (f Flip) print_flags() {
	mut buf := ''
	flags := f.flag_metas__

	mut flag_names := []string{}
	for flag in flags {
		flag_names << flag.label
	}

	if flags.len != 0 {
		buf += 'Flags:\n'
		for flag in flags {
			buf += flag.parse_info(f) + '\n'
		}
		buf += '\n'
	}
	print(buf)
}

fn (f Flip) print_subcommands() {
	mut buf := ''
	subs := f.subcommands

	mut sub_names := []string{}
	for sub in subs {
		sub_names << sub.name
	}

	mut strings := map[string][]string{}

	for sub in subs {
		strings[sub.category] << sub.parse_info(f)
	}

	for cat, title in f.categories {
		if !f.subcommands.category_used(cat) {
			continue
		}

		buf += '* ${title}:\n'
		for s in strings[cat] {
			buf += '${s}\n'
		}
		buf += '\n'
	}
	print(buf)
}

fn (meta FlagMeta) parse_info(f Flip) string {
	padding := f.help_padding
	mut str := '${get_spaces(padding.left)}-${meta.label}'

	usage := meta.usage.split('\n')
	for i, line in usage {
		if i != 0 {
			str += '\n${get_spaces(padding.left + meta.label.len +
				f.max_name_len__ - meta.label.len + padding.right)}${line}'
			continue
		}
		str += '${get_spaces(f.max_name_len__ - meta.label.len + padding.right - 1)}${line}'
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
			str += '\n${get_spaces(padding.left + f.max_name_len__ + padding.right)}${line}'
			continue
		}
		str += '${get_spaces(f.max_name_len__ - label_len + padding.right)}${line}'
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

fn get_spaces(i int) string {
	mut s := ''
	for _ in 0 .. i {
		s += ' '
	}
	return s
}

fn get_char(i int, ch string) string {
	mut s := ''
	for _ in 0 .. i {
		s += ch
	}
	return s
}

fn (f Flip) get_sub_names() []string {
	mut buf := []string{}
	for sub in f.subcommands {
		buf << sub.name
	}
	return buf
}

fn (f Flip) get_sub(name string) ?Flip {
	for sub in f.subcommands {
		if sub.name == name || name in sub.alias {
			return sub
		}
	}
	return none
}

fn (mut f Flip) set_max_length() {
	mut flag_names := []string{}
	mut sub_names := []string{}

	flags := f.flag_metas__
	subs := f.subcommands

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

	f.max_name_len__ = max(a, b)
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
