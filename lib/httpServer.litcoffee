
# Routes implementation using Express

	express = require('express')
	_ = require('lodash')
	async = require('async')

## Module's private variables

	app = null

	builtInFunctions =
		'_': (context, handlerData, req, res, nextFn) ->
			console.log handlerData
			res.status(501).send({})
		'get-metadata': (context, handlerData, req, res, nextFn) ->
			res.send(context.metadata)
		'get-ping': (context, handlerData, req, res, nextFn) ->
			res.send({timestamp: new Date().getTime()})
		'skip': (context, handlerData, req, res, nextFn) ->
			console.log handlerData
			nextFn()

## Module's private functions

Add Express app object routes and resolve early all the functions that will have to be called during responding to requests.

	addRouteGroup = (context, app, group) ->

		executeStack = (stack, req, res, next) ->
			async.eachSeries stack, (fn, nextFn) ->
				fn req, res, nextFn
				, next

		resolveStack = (stack) ->
			return _.map stack, (data, name) ->
				return context.resolveStackFunction module, name, data

		addAppRoute = (root, route, layer) ->
			verb = route.toLowerCase()
			handler = layer

			beforeFns = resolveStack group.before

			resolvedFn = undefined
			if _.isString handler
				resolvedFn = exports.resolveStackFunction context, handler
			else if _.isObject(handler) and _.isString(handler._)
				resolvedFn = exports.resolveStackFunction context, handler._, handler

			throw new Error('Cannot resolve ' + JSON.stringify(handler)) if not _.isFunction resolvedFn

			afterFns = resolveStack group.after

			stack = beforeFns.concat resolvedFn, afterFns

			app[verb] root, (req, res, next) ->
				executeStack stack, req, res, next

		resolveRoute = (root, route, layer) ->
			if route[0] == '/'
				newRoot = root + route
				_.each layer, (sublayer, subroute) ->
					resolveRoute newRoot, subroute, sublayer
			else
				addAppRoute root, route, layer

		_.each group.routes, (routeData, route) ->
			resolveRoute '', route, routeData

## Module's exported methods

	exports.init = (context, cake, layerData) ->
		app = express()

		_.each layerData, (group, name) ->
			addRouteGroup context, app, group

		port = context.config.port
		app.listen port, (err) ->
			console.log(err) if err
			console.log 'listening on port', port

	exports.resolveStackFunction = (context, name, data) ->

		fn = builtInFunctions[name] || builtInFunctions['skip']
		return undefined if not _.isFunction fn

		# Return function that will forward all the passed arguments.
		return fn.bind(undefined, context, data)
