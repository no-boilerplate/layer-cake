
	_ = require('lodash')

## Module's private variables

	nano = null
	db = null

## Module's private methods

	get = (id, callback) ->
		db.get id, callback

	post = (id, data, callback) ->
		doc = _.clone data
		doc._id = id
		db.insert doc, callback

## Module's exported methods

	exports.init = (driverData) ->
		console.log driverData
		nano = require('nano')(driverData.config.serverUrl)
		nano.db.create(driverData.config.databaseName)
		db = nano.db.use(driverData.config.databaseName)

	exports.act = (verb, model, ids, data, callback) ->
		id = model + '-' + ids[model]
		switch verb
			when 'GET' then get id, callback
			when 'POST' then post id, data, callback
			else callback(new Error('Verb ' + verb + ' is not implemented'))
