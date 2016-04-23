
# HTTP Express driver

	_ = require('lodash')
	express = require('express')
	async = require('async')
	deepExtend = require('deep-extend')

## Module's private variables

	app = null

	builtInFunctions =
		'_': (kitchen, handlerData, req, res, candidateModelName, nextFn) ->
			kitchen.modules.store.default.act req.method, candidateModelName, req.params, req.query, req.body, (err, result, next) ->
				return res.send(err).status(500) if err
				response = {}
				response[candidateModelName] = result
				response.meta =
					next: next
					limit: req.query.limit
				res.send(response)

		'get-metadata': (kitchen, handlerData, req, res, candidateModelName, nextFn) ->
			res.send(kitchen.metadata)

		'get-ping': (kitchen, handlerData, req, res, candidateModelName, nextFn) ->		
			res.send({timestamp: new Date().getTime()})

		'eval': (kitchen, handlerData, req, res, candidateModelName, nextFn) ->
			eval handlerData.params
			nextFn()

		'skip': (kitchen, handlerData, req, res, candidateModelName, nextFn) ->
			nextFn()

	isParamSubpathRegex = /^\/:/

## Module's private functions

Add Express app object routes and resolve early all the functions that will have to be called during responding to requests.

	addRouteGroup = (kitchen, app, group) ->

		executeStack = (stack, candidateModelName, req, res, next) ->
			async.eachSeries stack, (fn, nextFn) ->
				fn req, res, candidateModelName, nextFn
				, next

		resolveStack = (stack) ->
			return _.map stack, (data, name) ->
				return kitchen.resolveStackFunction module, name, data

		# We need to keep track of the last model candidate name.
		lastModelCandidateName = null

		addAppRoute = (root, route, layer) ->
			verb = route.toLowerCase()
			handler = layer

			beforeFns = resolveStack group.before

			resolvedFn = undefined
			if _.isString handler
				resolvedFn = exports.resolveStackFunction kitchen, handler, handler
			else if _.isObject(handler) and _.isString(handler.action)
				resolvedFn = exports.resolveStackFunction kitchen, handler.action, handler

			throw new Error('Cannot resolve ' + JSON.stringify(handler)) if not _.isFunction resolvedFn

			afterFns = resolveStack group.after

			stack = beforeFns.concat resolvedFn, afterFns

			# We need a closure here as we are essentially generating a function within a loop
			# and the lastModelCandidateName will keep changing after the function has been created.
			executeStackClosure = (modelCandidateName) ->
				return (req, res, next) ->
					executeStack stack, modelCandidateName, req, res, next

			app[verb] root, executeStackClosure(lastModelCandidateName)

		resolveRoute = (root, route, layer) ->
			if route[0] == '/'
				newRoot = root + route
				lastModelCandidateName = route.substr(1) if not isParamSubpathRegex.test(route)
				_.each layer, (sublayer, subroute) ->
					resolveRoute newRoot, subroute, sublayer
			else
				addAppRoute root, route, layer

		_.each group.routes, (routeData, route) ->
			resolveRoute '', route, routeData

## Exported functions

	exports.init = (kitchen, driverData) ->
		app = express()

		bodyParser = require('body-parser')
		app.use bodyParser.json()

		_.each driverData.groups, (group, name) ->
			addRouteGroup kitchen, app, group

		port = kitchen.config.port
		app.listen port, (err) ->
			console.log(err) if err
			console.log 'listening on port', port

	exports.resolveStackFunction = (kitchen, name, data) ->

		fn = builtInFunctions[name] || builtInFunctions['skip']
		return undefined if not _.isFunction fn

		# Return function that will forward all the passed arguments.
		return fn.bind(undefined, kitchen, data)
