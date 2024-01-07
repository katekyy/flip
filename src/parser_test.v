module flip

fn (fp FlagParser) assert_flag_value(key string, val string) bool {
	return fp.get(key) or { return false }.value or { return false } == val
}

fn test_normal() {
	mut fp := new_flag_parser()
	fp.add_flag(.bool, name: 'abc')
	fp.add_flag(.bool, name: 'bca', short: `b`)
	fp.add_flag(.float, name: 'f')
	fp.parse(['-abc', 'false', '-b', '-f', '0.2'])!
	assert fp.assert_flag_value('abc', 'false')
	assert fp.assert_flag_value('bca', 'true')
	assert fp.assert_flag_value('f', '0.2')
}
