import flip
import os

fn main() {
	mut app := flip.new_app(
		execute: fn (_ flip.Flip, args []string) ! {
			println(args.join(' '))
		}
		force_skip_cmds: true
		disable_help: true
	)
	app.init(os.args)
	app.parse()!
}
