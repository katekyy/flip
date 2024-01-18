module flip

pub enum FlagType {
	bool
	float
	int
	string
}

@[params]
pub struct FlagOptions {
pub mut:
	name        string
	short       ?rune
	description string
}

@[heap; noinit]
pub struct Flag {
pub mut:
	name        string
	shorthand   rune
	description string
	value       ?string
	typ         FlagType
	// Index of the argument where the flag was found. -1 if not found.
	idx     int = -1
	val_idx int = -1
}

@[noinit]
pub struct FlagParser {
pub:
	// Ignores undeclared flags
	ignore_unknown_flags bool
mut:
	idx int = -1
pub mut:
	flags []&Flag
	args  []string
}

// new_flag_parser returns a new instance of the flag parser
pub fn new_flag_parser(ignore_unknown_flags bool) &FlagParser {
	return &FlagParser{
		ignore_unknown_flags: ignore_unknown_flags
	}
}

// add_flag desclares a flag for the parser to parse.
// The parser will mutate the flags inside of it while parsing
pub fn (mut p FlagParser) add_flag(typ FlagType, opts FlagOptions) {
	if opts.name.len <= 0 {
		panic('flag must have a name')
	}
	if opts.name.contains(' ') {
		panic('flag name cannot contain any spaces')
	}
	p.flags << &Flag{
		name: opts.name
		shorthand: opts.short or { ` ` }
		description: opts.description
		typ: typ
	}
}

fn (mut p FlagParser) next() ?string {
	if p.idx + 1 >= p.args.len {
		return none
	}
	p.idx++
	return p.args[p.idx]
}

// parse parses the given array of args and looks for flags that were declared with `add_flag`,
// if the argument doesn't start with a dash nor a double dash, it ignores it.
@[direct_array_access]
pub fn (mut p FlagParser) parse(args []string) ! {
	p.idx = -1
	p.args = args
	root: for arg in p {
		if arg.len <= 1 && arg[0] == `-` {
			continue
		}
		if arg[0] == `-` {
			mut dash_len := 1
			if arg[1] == `-` {
				dash_len++
			}
			for mut flag in p.flags {
				if arg.len - dash_len == 1 {
					if flag.shorthand == arg[arg.len - 1] {
						flag.flag_value_from_next(p)!
						continue root
					}
				}
				if flag.name == arg[dash_len..] {
					flag.flag_value_from_next(p)!
					continue root
				}
			}
			if !p.ignore_unknown_flags {
				return error('unknown flag ${arg[dash_len..]}')
			}
		}
	}
}

@[direct_array_access]
fn (mut flag Flag) flag_value_from_next(p FlagParser) ! {
	if flag.idx >= 0 {
		return error('flag ${flag.name} ' + if flag.shorthand != ` ` {
			'(${flag.shorthand}) '
		} else {
			''
		} + 'was already encountered')
	}
	flag.idx = p.idx
	peeked := p.args[p.idx + 1] or { '' }
	match flag.typ {
		.bool {
			if is_bool(peeked) {
				flag.val_idx = p.idx + 1
				flag.value = peeked
				return
			}
			flag.value = true.str()
			return
		}
		.string {
			if peeked.len > 0 && peeked[0] != `-` {
				flag.value = parse_slash_dash(peeked)
				flag.val_idx = p.idx + 1
				return
			}
		}
		.int {
			if is_int(peeked) {
				flag.value = peeked
				flag.val_idx = p.idx + 1
				return
			}
		}
		.float {
			if is_float(peeked) {
				flag.value = peeked
				flag.val_idx = p.idx + 1
				return
			}
		}
	}
	return error('flag ${flag.name} (${flag.shorthand}) expected ${flag.typ} value')
}

fn parse_slash_dash(s string) string {
	idx := s.index('\\-') or { return s }
	return s[..idx] + parse_slash_dash(s[idx + 1..])
}

// get returns the flag with name `key`, if it wasn't found it returns none.
// If it didn't exist in the first place, it panics.
pub fn (p FlagParser) get(key string) ?&Flag {
	for flag in p.flags {
		if flag.name == key {
			if flag.idx < 0 {
				return none
			}
			return flag
		}
	}
	panic('flag ${key} does not exist')
}
