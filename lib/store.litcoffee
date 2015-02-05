
	_ = require('lodash')

## Module's public variables

	exports.default = null

## Module's exported methods

	exports.init = (kitchen, cake, layer) ->
		_.each layer, (storeData, name) ->
			console.log name, storeData

			store = require('./store/driver/' + storeData.driver)
			store.init storeData

			if name == 'default'
				exports.default = store

	exports.resolveStackFunction = (kitchen, name, data) ->

		fn = builtInFunctions[name] || builtInFunctions['skip']
		return undefined if not _.isFunction fn

		# Return function that will forward all the passed arguments.
		return fn.bind(undefined, kitchen, data)