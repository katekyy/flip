import flip
import os

fn main() {
	mut app := flip.new_app(
		commands: [
			flip.new_command(
				name: 'joke'
				description: 'Tell a joke'
				execute: fn (_ flip.Flip, _ []string) ! {
					println("There's unfortunately no joke to tell...")
				}
			),
			flip.new_command(
				name: 'sub'
				description: 'A subcommand'
				commands: [
					flip.new_command(
						name: 'sub'
						description: 'Another subcommand'
					),
				]
			),
		]
	)
	app.init(os.args)
	app.parse()!
}
