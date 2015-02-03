
# Routes implementation using Express

	express = require('express')
	_ = require('lodash')

Module's private variables

	app = null

	interpreter = (context, req, res, data) ->

		if _.isString data
			resolvedFn = exports.resolve data
			if resolvedFn
				return resolvedFn context, req, res

		res.status(404).send({})

	addAppRoute = (context, app, root, route, layer) ->
		if route[0] == '/'
			newRoot = root + route
			_.each layer, (sublayer, subroute) ->
				addAppRoute context, app, newRoot, subroute, sublayer
		else
			verb = route.toLowerCase()
			app[verb] root, (req, res) ->
				interpreter context, req, res, layer

## Module's exported methods

	exports.init = (context, cake, layerData) ->
		app = express()

		_.each layerData.routes, (sublayer, subroute) ->
			addAppRoute context, app, '', subroute, sublayer

		port = context.config.port
		app.listen port, (err) ->
			console.log(err) if err
			console.log 'listening on port', port

	functions =
		'_': (context, req, res) ->
			res.status(501).send({})
		'get-metadata': (context, req, res) ->
			res.send(context.metadata)
		'get-ping': (context, req, res) ->
			res.send({timestamp: new Date().getTime()})

	exports.resolve = (name) ->
		return functions[name]
