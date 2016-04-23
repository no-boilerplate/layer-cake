
Entry point

	_ = require('lodash')

	if process.argv.length <= 2
		console.log 'Specify layer-cake script'
		return

Load the YAML script for layer-cake.

	script = process.argv[2]

	yaml = require 'js-yaml'
	fs = require 'fs'

	cake = undefined
	try
		cake = yaml.safeLoad(fs.readFileSync(script, 'utf8'))
	catch e
		return console.log(e)

Bake layer-cake in the kitchen

	kitchen = require('./lib/kitchen')
	kitchen.bake cake
