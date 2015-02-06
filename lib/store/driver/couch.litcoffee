
	_ = require('lodash')

## Module's private variables

	nano = null
	db = null
	kitchen = null
	initializedModels = {}

## Module's private methods

	modelDesignDocName = (model) -> 'layer-cake-model-' + model
	modelViewName = (model) -> 'by-model-' + model

	respond = (callback) ->
		return (err, result) ->
			err = kitchen.error.create('Error while accessing store', err.statusCode) if err
			callback err, result

	get = (id, callback) ->
		db.get id, respond(callback)

When requesting a set of model documents we need to check if the implicit model has been created. This check is performed once per session.

Each model is in a different design document which allows creation/updating to be done separately. If they were in the same doc, all the views would have to be rebuilt every time a single one changed or was added.

	updateModelViewIfNeeded = (model, callback) ->
		return callback() if not _.isUndefined initializedModels[model]

		modelDesignName = '_design/' + modelDesignDocName(model)
		db.get modelDesignName, (err, designDoc) ->
			return callback(err) if err && err.statusCode != 404

			design =
				views: {}
			design.views[modelViewName(model)] =
				map:
					'function (doc) { if (doc["layer-cake-model"] === "' + model + '") return emit(doc.model, null); }'

			# Update the design doc if it has changed or doesn't exist.
			# These conditions avoid rebuilding the view unnecessarily.
			if !designDoc
				designDoc = design
			else
				return callback() if _.isEqual(designDoc.views, design.views)
				designDoc.views = design.views

			db.insert designDoc, modelDesignName, callback

	getSet = (model, id, limit, callback) ->
		updateModelViewIfNeeded model, (err) ->
			if err
				kitchen.error.raise 'Unexpected error occurred while updating models', err.statusCode
			params =
				startKey: id
				limit: limit
				include_docs: true
			db.view modelDesignDocName(model), modelViewName(model), params, (err, docs) ->
				return callback(err) if err
				callback null, _.map docs.rows, (row) -> row.doc

	post = (model, id, data, callback) ->
		doc = _.clone data
		if id
			doc._id = id
		doc["layer-cake-model"] = model

		respondCallback = respond(callback)
		db.insert doc, (err, result) ->
			return respondCallback(err) if err or not result
			doc._id = result.id
			doc._rev = result.rev
			respondCallback null, doc

	destroy = (id, rev, callback) ->
		db.destroy id, rev, respond(callback)

## Module's exported methods

	exports.init = (givenKitchen, driverData) ->
		kitchen = givenKitchen
		nano = require('nano')(driverData.config.serverUrl)
		nano.db.create(driverData.config.databaseName)
		db = nano.db.use(driverData.config.databaseName)

	exports.act = (verb, model, ids, data, callback) ->
		modelId = ids[model]
		id = if modelId then model + '-' + modelId else undefined
		switch verb
			when 'GET', 'HEAD'
				if id
					get id, callback
				else
					getSet model, id, 100, callback
			when 'POST' then post model, id, data, callback
			when 'DELETE' then destroy id, data._rev, callback
			else callback(new Error('Verb ' + verb + ' is not implemented'))
