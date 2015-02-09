
## Used modules

	_ = require('lodash')

## Variables

	nano = null
	db = null
	kitchen = null
	config = null
	initializedModels = {}

## Constants

	defaultDesignDocName = 'layer-cake'
	viewName = 'view'

## Private methods

	modelField = () -> config.modelField or 'layer-cake-model'
	getDesignDocName = (model, params) ->
		return defaultDesignDocName if _.isEmpty params
		designDocName = _.reduce params, (designDocName, modelId, modelName) ->
			designDocName += '-' + modelName
		, 'layer-cake'
		designDocName += '-' + model
		return designDocName

	respond = (callback) ->
		return (err, result) ->
			err = kitchen.error.create('Error while accessing store', err.statusCode) if err
			callback err, result

	get = (model, id, params, callback) ->
		db.get id, (err, result) ->
			return callback(err) if err
			# Check if the entire map of params matches the retrieved doc.
			# If it doesn't we *must not* return it as that would be a
			# data leakage.
			matches = _.every params, (value, name) ->
				name == model or result[name] == value
			return callback(null, result) if matches
			callback()

When requesting a set of model documents we need to check if the implicit model has been created. This check is performed once per session.

Each model is in a different design document which allows creation/updating to be done separately. If they were in the same doc, all the views would have to be rebuilt every time a single one changed or was added.

	getSet = (model, id, params, next, limit, callback) ->

		designDocName = getDesignDocName model, params
		designDocId = '_design/' + designDocName
		console.log designDocName

		updateModelIdViewIfNeeded = (callback) ->

			return callback() if not config.createImplicitViews

			return callback() if not _.isUndefined initializedModels[model]

			db.get designDocId, (err, designDoc) ->
				return callback(err) if err && err.statusCode != 404

				design =
					views: {}
				if _.isEmpty params
					design.views[viewName] =
						map:
							'function (doc) {	\
								model = doc["' + modelField() + '"];	\
								if (model) {	\
									return emit([model, doc._id], null);	\
								}	\
							}'
				else
					models = _.reduce params, (models, modelId, modelName) ->
						if _.isEmpty models
							models = 'doc.' + modelName
						else
							models += ', doc.' + modelName
					, ''
					design.views[viewName] =
						map:
							'function (doc) {	\
								model = doc["' + modelField() + '"];	\
								if (model === "' + model + '") {	\
									return emit([' + models + ', doc._id])
								}	\
							}'

				# Update the design doc if it has changed or doesn't exist.
				# These conditions avoid rebuilding the view unnecessarily.
				if !designDoc
					designDoc = design
				else
					return callback() if _.isEqual(designDoc.views, design.views)
					designDoc.views = design.views

				db.insert designDoc, designDocId, callback

		updateModelIdViewIfNeeded (err) ->

			if err
				console.log err
				kitchen.error.raise 'Unexpected error occurred while updating models', err.statusCode, err

			keyBase = []
			if _.isEmpty params
				keyBase = [model]
			else
				keyBase = _.reduce params, (ids, modelId, modelName) ->
					console.log ids, modelId, modelName
					ids.push(modelId)
					return ids
				, []

			params =
				startkey: if next then keyBase.concat(next) else keyBase
				endkey: keyBase.concat({})
				limit: if limit then parseInt(limit) + 1 else undefined
				include_docs: true

			db.view designDocName, viewName, params, (err, result) ->
				return callback(err) if err
				docs = _.map result.rows, (row) -> row.doc
				newNext = undefined
				if params.limit and docs.length == params.limit
					console.log docs
					nextDoc = docs.pop()
					newNext = nextDoc._id
				callback null, docs, newNext

	post = (model, id, data, params, callback) ->

		doc = _.clone data
		if id
			doc._id = id
		doc[modelField()] = model
		_.each params, (value, name) ->
			if name != model
				doc[name] = value

		respondCallback = respond(callback)
		db.insert doc, (err, result) ->
			return respondCallback(err) if err or not result
			doc._id = result.id
			doc._rev = result.rev
			respondCallback null, doc

	destroy = (id, rev, callback) ->
		db.destroy id, rev, respond(callback)

## Exported methods

	exports.init = (givenKitchen, driverData) ->
		kitchen = givenKitchen
		config = driverData.config
		nano = require('nano')(config.serverUrl)
		nano.db.create(config.databaseName)
		db = nano.db.use(config.databaseName)

	exports.act = (verb, model, params, query, data, callback) ->

		modelId = params[model]
		id = if modelId then modelId else undefined
		switch verb
			when 'GET', 'HEAD'
				if id
					get model, id, params, callback
				else
					getSet model, id, params, query.next, query.limit, callback
			when 'POST' then post model, id, data, params, callback
			when 'DELETE' then destroy id, data._rev, callback
			else callback(new Error('Verb ' + verb + ' is not implemented'))
