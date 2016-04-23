
	_ = require('lodash')
	
	module.exports.bake = (cake) ->

Create kitchen object with environment, modules and other entries that are used by the rest of the system.

		kitchen =
			env: process.env.NODE_ENV
			modules:
				http: require('./http')
				store: require('./store')
				error: require('./error')

Function that resolves the stack functions by their name. It first tries to resolve the name in the module that invoked it and if that fails it tries to resolves it in the registered modules.

		# We had to finish creating kitchen before defining this function
		# as it uses kitchen itself.
		kitchen.resolveStackFunction = (module, name, data) ->
			fn = module.exports.resolveStackFunction kitchen, name, data
			return fn if _.isFunction(fn)

			fn = _.filter kitchen.modules, (module, name) ->
				return module.exports.resolveStackFunction kitchen, name, data

			return fn if _.isFunction fn

			throw new Error('Cannot resolve ' + name + ' name')

Deep merge the common data and environment data for all the layers.

		deepExtend = require('deep-extend')

		bakedCake = {}
		_.each cake, (layer, name) ->
			layerData = _.clone layer.common
			deepExtend layerData, layer[kitchen.env]
			bakedCake[name] = layerData

		kitchen.config = bakedCake.config
		kitchen.metadata = bakedCake.metadata
		kitchen.error = kitchen.modules.error
		kitchen.error.init kitchen

Evaluate all the data that can be evaluated before initializing the modules.

		evaluateObject = (object) ->
			return if not _.isObject(object)
			_.each object, (value, name) ->
				if _.isString(value) and not _.isEmpty(value) and value[0] == '$'
					envVariableName = value.substring(1)
					envVariableValue = process.env[envVariableName]
					if _.isUndefined envVariableValue
						throw new Error('Undefined process environment variable ' + envVariableName)
					object[name] = envVariableValue
				else if _.isObject(value)
					evaluateObject value

		_.each bakedCake, (layer) ->
			evaluateObject layer

Initialize all the modules of baked cake.

		_.each bakedCake, (layer, name) ->
			layerModule = kitchen.modules[name]
			if layerModule
				layerModule.init kitchen, cake, layer
