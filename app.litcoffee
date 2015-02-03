
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

Create context object with environment, registry and other entries that are used by the rest of the system.

	context =
		env: process.env.NODE_ENV
		registry:
			httpServer: require('./lib/httpServer')

Deep merge the common data and environment data for all the layers.

	deepExtend = require('deep-extend')

	bakedCake = {}
	_.each cake, (layer, name) ->
		layerData = _.clone layer['_']
		deepExtend layerData, layer[context.env]
		bakedCake[name] = layerData

	context.config = bakedCake.config
	context.metadata = bakedCake.metadata

Evaluate all the data that can be evaluated before initializing the modules.

	evaluateObject = (object) ->
		return if not _.isObject(object)
		_.each object, (value, name) ->
			if _.isString(value) and not _.isEmpty(value) and value[0] == '$'
				object[name] = process.env[value.substring(1)]
			else if _.isObject(value)
				evaluateObject value

	_.each bakedCake, (layer) ->
		evaluateObject layer

Initialize all the modules of baked cake.

	_.each bakedCake, (layer, name) ->
		layerModule = context.registry[name]
		if layerModule
			layerModule.init context, cake, layer
	