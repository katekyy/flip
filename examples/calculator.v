import flip
import os

fn main() {
	mut app := flip.new_app(
		execute: fn (_ flip.Flip, args []string) ! {
			println(eval_rpn(args)!)
		}
		// Unlike `force_skip_cmds` it just doesn't error out when it can't resolve the command path.
		ignore_unknown_cmds: true
	)
	app.init(os.args)
	app.parse()!
}

fn eval_rpn(equation []string) !int {
	mut stack := []int{}
	for expr in equation {
		if !is_positive_number(expr) {
			if stack.len < 2 {
				return error('too few numbers on the stack')
			}
			match expr {
				'/' {
					second := stack.pop()
					first := stack.pop()
					stack << first / second
					continue
				}
				'x' {
					second := stack.pop()
					first := stack.pop()
					stack << first * second
					continue
				}
				'-' {
					second := stack.pop()
					first := stack.pop()
					stack << first - second
					continue
				}
				'+' {
					second := stack.pop()
					first := stack.pop()
					stack << first + second
					continue
				}
				else {
					return error('unknown operator ${expr}')
				}
			}
		}
		stack << expr.int()
	}
	if stack.len > 1 {
		return error('stack was not fully emptied')
	}
	if stack.len < 1 {
		return error('stack is empty')
	}
	return stack.pop()
}

fn is_positive_number(s string) bool {
	return (s == '0' || s.int() != 0) && s.int() >= 0
}
