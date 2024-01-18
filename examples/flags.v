import flip
import os

fn main() {
	mut app := flip.new_app(execute: cli_root_execute)
	app.init(os.args)
	app.string('message', `m`, 'Some option')
	app.parse()!
}

fn cli_root_execute(f flip.Flip, args []string) ! {
	f.get_string_opt('message') or { return error('flag "message" (-m) not specified') }
}
