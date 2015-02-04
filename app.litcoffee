
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

Create context object with environment, modules and other entries that are used by the rest of the system.

	context =
		env: process.env.NODE_ENV
		modules:
			httpServer: require('./lib/httpServer')

Function that resolves the stack functions by their name. It first tries to resolve the name in the module that invoked it and if that fails it tries to resolves it in the registered modules.

	# We had to finish creating context before defining this function
	# as it uses context itself.
	context.resolveStackFunction = (module, name, data) ->
		fn = module.exports.resolveStackFunction context, name, data
		return fn if _.isFunction(fn)

		fn = _.filter context.modules, (module, name) ->
			return module.exports.resolveStackFunction context, name, data

		return fn if _.isFunction fn

		throw new Error('Cannot resolve ' + name + ' name')

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
		layerModule = context.modules[name]
		if layerModule
			layerModule.init context, cake, layer
	