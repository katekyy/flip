module flip

// bool is a flag parser. It parses arguments passed to flip and returns the boolean value of the flag.
// Note: `bool` is unique to other parsers in this library.
// If the user passes the flag as an argument but that flag has no value, it returns the opposite of `default`.
pub fn (mut f Flip) bool(label string, default bool, usage string) bool {
	f.flag_metas__ << &FlagMeta{label, usage, default.str()}
	exists, tail := parse_flag(label, f.args)
	p := parse_bool(tail) or { !default && exists }
	f.flags << &Flag{label, p.str()}

	if exists {
		index := f.get_arg_idx('-' + label) or { return default }
		if index < f.args.len - 1 && f.args[index + 1][0].ascii_str() != '-' {
			f.args.delete(index + 1)
		}
		f.rem_arg('-' + label)
		return p
	}
	return default
}

// int is a flag parser. It parses arguments passed to flip and returns the integer value of the flag.
pub fn (mut f Flip) int(label string, default int, usage string) int {
	return f.impl_flag(label, default, usage, parse_int)
}

// string is a flag parser. It parses arguments passed to flip and returns the string value of the flag.
pub fn (mut f Flip) string(label string, default string, usage string) string {
	return f.impl_flag(label, default, usage, parse_string)
}

// float is a flag parser. It parses arguments passed to flip and returns the floating point value of the flag.
pub fn (mut f Flip) float(label string, default f64, usage string) f64 {
	return f.impl_flag(label, default, usage, parse_float)
}

fn (mut f Flip) impl_flag[T](label string, default T, usage string, func fn ([]string) ?T) T {
	f.flag_metas__ << &FlagMeta{label, usage, default.str()}
	exists, tail := parse_flag(label, f.args)
	p := func(tail) or { default }
	f.flags << &Flag{label, p.str()}

	if exists {
		index := f.get_arg_idx('-' + label) or { return default }
		if index < f.args.len - 1 {
			f.args.delete(index + 1)
		}
		f.rem_arg('-' + label)

		return p
	}
	return default
}

fn (mut f Flip) rem_arg(s string) {
	if s.is_blank() {
		return
	}
	mut args := []string{}
	for arg in f.args {
		if arg != s {
			args << arg
		}
	}
	f.args = args
}

fn (f Flip) get_arg_idx(s string) ?int {
	for i, arg in f.args {
		if arg == s {
			return i
		}
	}
	return none
}

fn parse_flag(s string, ss []string) (bool, []string) {
	mut i := 0
	for str in ss {
		i++
		if str[1..] == s {
			return true, ss[i..]
		}
	}
	return false, []string{}
}

fn parse_float(ss []string) ?f64 {
	for str in ss {
		if str[0].ascii_str() != '-' && is_float(str) {
			return str.f64()
		}
	}
	return none
}

fn parse_string(ss []string) ?string {
	for str in ss {
		if str[0].ascii_str() != '-' {
			return str
		}
	}
	return none
}

fn parse_int(ss []string) ?int {
	for str in ss {
		if str[0].ascii_str() != '-' && is_int(str) {
			return str.int()
		}
	}
	return none
}

fn parse_bool(ss []string) ?bool {
	for str in ss {
		if str[0].ascii_str() != '-' && is_bool(str) {
			return str.bool()
		}
	}
	return none
}

fn is_float(s string) bool {
	match s {
		'0.' + get_char(s.len - 2, '0') { return true }
		'.' + get_char(s.len - 1, '0') { return true }
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
	if s == get_char(s.len, '0') {
		return true
	}
	return s.int() != 0
}

fn is_bool(s string) bool {
	if s.to_upper() == 'FALSE' {
		return true
	}
	return s.bool()
}
