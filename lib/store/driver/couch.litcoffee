
## Used modules

	_ = require('lodash')

## Variables

	nano = null
	db = null
	kitchen = null
	config = null
	initializedModels = {}

## Constants

	designDocName = 'layer-cake'
	modelIdViewName = 'model-id'

## Private methods

	modelField = () -> config.modelField or 'layer-cake-model'

	respond = (callback) ->
		return (err, result) ->
			err = kitchen.error.create('Error while accessing store', err.statusCode) if err
			callback err, result

	get = (id, callback) ->
		db.get id, respond(callback)

When requesting a set of model documents we need to check if the implicit model has been created. This check is performed once per session.

Each model is in a different design document which allows creation/updating to be done separately. If they were in the same doc, all the views would have to be rebuilt every time a single one changed or was added.

	getSet = (model, id, next, limit, callback) ->

		designDocId = '_design/' + designDocName

		updateModelIdViewIfNeeded = (model, callback) ->
			return callback() if not _.isUndefined initializedModels[model]

			db.get designDocId, (err, designDoc) ->
				return callback(err) if err && err.statusCode != 404

				design =
					views: {}
				field = modelField()
				design.views[modelIdViewName] =
					map:
						'function (doc) {	\
							model = doc["' + field + '"];	\
							if (model) {	\
								return emit([model, doc._id], null);	\
							}	\
						}'

				console.log design

				# Update the design doc if it has changed or doesn't exist.
				# These conditions avoid rebuilding the view unnecessarily.
				if !designDoc
					designDoc = design
				else
					return callback() if _.isEqual(designDoc.views, design.views)
					designDoc.views = design.views

				db.insert designDoc, designDocId, callback

		updateModelIdViewIfNeeded model, (err) ->

			if err
				console.log err
				kitchen.error.raise 'Unexpected error occurred while updating models', err.statusCode, err

			params =
				startkey: if next then [model, next] else [model]
				endkey: [model, {}]
				limit: if limit then parseInt(limit) + 1 else undefined
				include_docs: true
			console.log params

			console.log designDocName, modelIdViewName

			db.view designDocName, modelIdViewName, params, (err, result) ->
				return callback(err) if err
				docs = _.map result.rows, (row) -> row.doc
				newNext = undefined
				if params.limit and docs.length == params.limit
					console.log docs
					nextDoc = docs.pop()
					newNext = nextDoc._id
				callback null, docs, newNext

	post = (model, id, data, callback) ->
		doc = _.clone data
		if id
			doc._id = id
		doc[modelField()] = model

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

	exports.act = (verb, model, params, data, callback) ->
		modelId = params[model]
		id = if modelId then model + '-' + modelId else undefined
		switch verb
			when 'GET', 'HEAD'
				if id
					get id, callback
				else
					getSet model, id, params.next, params.limit, callback
			when 'POST' then post model, id, data, callback
			when 'DELETE' then destroy id, data._rev, callback
			else callback(new Error('Verb ' + verb + ' is not implemented'))
