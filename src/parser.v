module flip

import strings { repeat_string }

pub struct Flag {
pub mut:
	label       string
	short       ?rune
	description string
mut:
	value       string
	private_for []string
	private     bool
	found       bool
}

// str returns the string version of flag
pub fn (f Flag) str() string {
	return '${f.label}: "${f.value}"'
}

// new returns a pointer to a newely created flag
[direct_array_access]
pub fn Flag.new(label string, short ?rune, value ?string, description string) &Flag {
	mut desc := description.trim_space()
	mut private_for := []string{}
	mut private := false

	if desc.len > 2 && desc[0].ascii_str() == '[' {
		idx := desc.index(']') or { -1 }
		if idx > 0 {
			private_for = desc[1..idx].split(',').map(it.trim_space())
			private = true
			desc = desc[idx + 1..].trim_space()
		}
	}
	return &Flag{
		label: label
		short: short
		value: value or { '' }
		description: desc
		private_for: private_for
		private: private
	}
}

// bool looks for a flag in arguments. If it finds one, it'll return it's value.
// Note: Boolean type flags do not need to see the value of them.
// If it finds only the flag without it's value, it'll return the opposite of `default`
pub fn (mut f Flip) bool(label string, short ?rune, default bool, description string) bool {
	return f.flag_parser.parse_bool(label, short, default, description)
}

// string looks for a flag in arguments. If it finds one, it'll return it's value.
pub fn (mut f Flip) string(label string, short ?rune, default string, description string) string {
	return f.flag_parser.parse_value(label, short, default, description, fn (s string) ?string {
		return s
	})
}

// int looks for a flag in arguments. If it finds one, it'll return it's value.
// If it can't cast that value to an integer (int), it'll return `default`.
pub fn (mut f Flip) int(label string, short ?rune, default int, description string) int {
	return f.flag_parser.parse_value(label, short, default, description, fn (s string) ?int {
		if is_int(s) {
			return s.int()
		}
		return none
	})
}

// float looks for a flag in arguments. If it finds one, it'll return it's value.
// If it can't cast that value to an float (f64), it'll return `default`.
pub fn (mut f Flip) float(label string, short ?rune, default f64, description string) f64 {
	return f.flag_parser.parse_value(label, short, default, description, fn (s string) ?f64 {
		if is_float(s) {
			return s.f64()
		}
		return none
	})
}

pub struct FlagParser {
mut:
	flags           []&Flag
	args            []string
	idx_dashdash    int = -1
	before_dashdash []string
}

// new creates a new pointer to `FlagParser` with the passed arguments.
pub fn FlagParser.new(args []string) &FlagParser {
	mut p := &FlagParser{
		args: args
	}
	p.split_arrays()
	return p
}

[direct_array_access]
fn (mut p FlagParser) split_arrays() {
	p.before_dashdash = p.args
	idx := p.args.index('--')
	if idx > -1 {
		p.idx_dashdash = idx
		p.before_dashdash = p.args[..idx]
		if idx < p.args.len - 1 {
			p.args = p.args[idx + 1..]
			return
		}
		p.args = []
	}
}

fn (mut p FlagParser) join_arrays() {
	mut buf := p.before_dashdash.clone()
	if p.idx_dashdash > -1 {
		buf << p.args
	}
	p.args = buf
}

fn (mut f Flip) move_fields() {
	f.args = f.flag_parser.args
	f.flags = f.flag_parser.flags.map(|flag| *flag)
}

// parse_bool is the base function for `bool`.
[direct_array_access]
pub fn (mut p FlagParser) parse_bool(label string, sh ?rune, default bool, description string) bool {
	args := p.before_dashdash

	mut val := default
	mut names := ['--${label}', '-${label}']
	if sh != none {
		names << ['--${sh.str()}', '-${sh.str()}']
	}

	for idx, arg in args {
		hand_len := get_len(arg, names)
		if hand_len > 0 {
			if arg.len == hand_len {
				val_idx := idx + 1
				if args.len >= val_idx + 1 && !(args[val_idx].starts_with('-')
					|| args[val_idx].starts_with('--')) {
					if is_bool(args[val_idx]) {
						val = args[val_idx].to_lower().bool()
						p.clear_args_at([idx, val_idx])
						break
					}
				}
				val = !default
				p.before_dashdash.delete(idx)
				break
			}
			if arg.len > hand_len {
				if arg[hand_len..hand_len + 1] != '=' {
					break
				}
				if is_bool(arg[hand_len + 1..]) {
					val = arg[hand_len + 1..].to_lower().bool()
				}
				p.before_dashdash.delete(idx)
				break
			}
		}
		// TODO:
		// dash_len := get_len(arg, ['-', '--'])
		// dump(dash_len)
		// if dash_len > 0 {
		// 	for ridx, r in arg.runes() {
		// 		if r == sh or { break } {
		// 			dump(label)
		// 			uw_short := sh or { break }
		// 			p.before_dashdash = []string{}
		// 			// // dump(p.before_dashdash)
		// 			// // p.before_dashdash << args
		// 			// dump(p.before_dashdash)
		// 			// p.before_dashdash << args[idx][..ridx]
		// 			// dump(p.before_dashdash)
		// 			// p.before_dashdash << args[idx][ridx..ridx + dash_len]
		// 			tail := args[idx][dash_len..].split('').filter(|x| x != uw_short.str()).map(|x| '-${x}')
		// 			// dump(label)
		// 			if tail.len > 0 {
		// 				p.before_dashdash << tail
		// 				p.before_dashdash << args[..idx]
		// 			}
		// 			dump(p.before_dashdash)
		// 			val = !default
		// 			break
		// 		}
		// 	}
		// }
	}
	p.flags << Flag.new(label, sh, val.str(), description)
	return val
}

// parse_value is the base function for `string`, `int` and `float`.
[direct_array_access]
pub fn (mut p FlagParser) parse_value[T](label string, sh ?rune, default T, description string, from_str fn (string) ?T) T {
	args := p.before_dashdash

	mut val := default
	mut names := ['--${label}', '-${label}']
	if sh != none {
		names << ['--${sh.str()}', '-${sh.str()}']
	}

	for idx, arg in args {
		hand_len := get_len(arg, names)
		if hand_len > 0 {
			if arg.len == hand_len {
				val_idx := idx + 1
				if args.len >= val_idx + 1 && !(args[val_idx].starts_with('-')
					|| args[val_idx].starts_with('--')) {
					val = from_str(args[val_idx]) or { break }
					p.clear_args_at([idx, val_idx])
					break
				}
			}
			if arg.len > hand_len {
				if arg[hand_len..hand_len + 1] != '=' {
					break
				}
				val = from_str(arg[hand_len + 1..]) or { break }
				p.before_dashdash.delete(idx)
				break
			}
		}
	}
	p.flags << Flag.new(label, sh, val.str(), description)
	return val
}

fn starts_with(s string, vals []string) bool {
	mut b := false
	for val in vals {
		b = s.starts_with(val)
	}
	return b
}

fn get_len(s string, vals []string) int {
	mut len := -1
	for val in vals {
		if s.starts_with(val) {
			len = val.len
		}
	}
	return len
}

fn (mut p FlagParser) clear_args_at(idxs []int) {
	for i, idx in idxs.sorted(|x, y| x < y) {
		p.before_dashdash.delete(idx - i)
	}
}

fn is_float(s string) bool {
	match s {
		'0.' + repeat_string('0', s.len - 2) { return true }
		'.' + repeat_string('0', s.len - 1) { return true }
		else {}
	}
	ss := s.split('.')
	if ss.len > 2 || ss.len < 2 {
		return is_int(s)
	}
	if (is_int(ss[0]) && is_int(ss[1])) || (ss[0].len < 1 && is_int(ss[1])) {
		return true
	}
	return false
}

fn is_int(s string) bool {
	if s == repeat_string('0', s.len) {
		return true
	}
	return s.int() != 0
}

[inline]
fn is_bool(s string) bool {
	sl := s.to_lower()
	return sl == 'false' || sl == 'true'
}
