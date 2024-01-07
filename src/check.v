module flip

fn is_bool(s string) bool {
	s_ := s.to_lower()
	return s_ == 'true' || s_ == 'false'
}

fn is_int(s string) bool {
	if s == '0' {
		return true
	}
	return s.int() != 0
}

fn is_float(s string) bool {
	begin := s.all_before('.')
	end := s.all_after('.').bytes()
	if end.len >= 1 && end.all(it == `0`) {
		if begin.len == 0 {
			return true
		}
		if begin == '0' {
			return true
		}
		return false
	}
	return is_int(s) || s.f64() != f64(0)
}
