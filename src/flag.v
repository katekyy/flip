module flip

// bool adds a flag of type bool to the internal flag parser
pub fn (mut f Flip) bool(name string, short ?rune, description string) {
	f.flag_parser.add_flag(.bool,
		name: name
		short: short
		description: description
	)
}

// string adds a flag of type string to the internal flag parser
pub fn (mut f Flip) string(name string, short ?rune, description string) {
	f.flag_parser.add_flag(.string,
		name: name
		short: short
		description: description
	)
}

// int adds a flag of type int to the internal flag parser
pub fn (mut f Flip) int(name string, short ?rune, description string) {
	f.flag_parser.add_flag(.int,
		name: name
		short: short
		description: description
	)
}

// float adds a flag of type float to the internal flag parser
pub fn (mut f Flip) float(name string, short ?rune, description string) {
	f.flag_parser.add_flag(.float,
		name: name
		short: short
		description: description
	)
}

// get_bool returns the flag with name `key` as a boolean.
// If it was not found, or if the flag type was not bool, it returns false.
pub fn (f Flip) get_bool(key string) bool {
	return f.get_bool_opt(key) or { false }
}

// get_bool_opt returns the flag with name `key` as a boolean.
// If it was not found, or if the flag type was not bool, it returns none.
pub fn (f Flip) get_bool_opt(key string) ?bool {
	mut flag := f.flag_parser.get(key) or { return none }
	if flag.typ == .bool {
		return flag.value or { return none }.bool()
	}
	panic('type of flag ${key} is ${flag.typ}, not bool, therefore it cannot be obtained')
}

// get_string returns the flag with name `key` as a string.
// If it was not found, or if the flag type was not int, it returns an empty string.
pub fn (f Flip) get_string(key string) string {
	return f.get_string_opt(key) or { '' }
}

// get_string_opt returns the flag with name `key` as a string.
// If it was not found, or if the flag type was not string, it returns none.
pub fn (f Flip) get_string_opt(key string) ?string {
	mut flag := f.flag_parser.get(key) or { return none }
	if flag.typ == .string {
		return flag.value or { return none }
	}
	panic('type of flag ${key} is ${flag.typ}, not string, therefore it cannot be obtained')
}

// get_int returns the flag with name `key` as a integer.
// If it was not found, or if the flag type was not int, it returns 0.
pub fn (f Flip) get_int(key string) int {
	return f.get_int_opt(key) or { 0 }
}

// get_int_opt returns the flag with name `key` as a integer.
// If it was not found, or if the flag type was not int, it returns none.
pub fn (f Flip) get_int_opt(key string) ?int {
	mut flag := f.flag_parser.get(key) or { return none }
	if flag.typ == .int {
		return flag.value or { return none }.int()
	}
	panic('type of flag ${key} is ${flag.typ}, not bool, therefore it cannot be obtained')
}

// get_float returns the flag with name `key` as a 64bit floating point number.
// If it was not found, or if the flag type was not float, it returns 0.
pub fn (f Flip) get_float(key string) f64 {
	return f.get_float_opt(key) or { f64(0) }
}

// get_float_opt returns the flag with name `key` as a 64bit floating point number.
// If it was not found, or if the flag type was not float, it returns none.
pub fn (f Flip) get_float_opt(key string) ?f64 {
	mut flag := f.flag_parser.get(key) or { return none }
	if flag.typ == .float {
		return flag.value or { return none }.f64()
	}
	panic('type of flag ${key} is ${flag.typ}, not bool, therefore it cannot be obtained')
}
