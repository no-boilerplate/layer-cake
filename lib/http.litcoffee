
	_ = require('lodash')

## Module's public variables

	exports.default = null

## Exported functions

	exports.init = (kitchen, cake, layer) ->
		_.each layer, (driverData, name) ->
			store = require('./http/driver/' + driverData.driver)
			store.init kitchen, driverData

			if name == 'default'
				exports.default = store
