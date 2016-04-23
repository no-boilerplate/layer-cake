
# Couchdb driver for LayerCake

This driver maps REST paths to Couchdb documents by doing the following:

1. Allows creation of documents with both specified IDs and automatically assigned IDs.
2. Creates documents from which one can reconstruct the entire REST path to them.
3. Allows direct retrieval of documents through GET /model/<model _id>/... paths.
4. Allows retrieval of set of documents through GET /model, /model1/<model _id>/model2, etc. paths.

1. Automatic _id value is a hash of model names and IDs thus ensuring uniqueness (e.g. hash(model + _id))
2. POST /model1 -> creates /model1/_id
3. POST /model1/<model1 _id>/model2 -> creates /model1/<model1 _id>/model2/_id
4. POST /model1/<model1 _id> -> creates /model1/<model1 _id>
5. Each general path (e.g. /model1[/<model1 _id], /model1/<model1 _id>/model2, etc.) has a separate view that:
    a)  is named after models (e.g. model1, model1_model2, etc.)
    b)  has mapping function that maps doc to array of model IDs (e.g. [model1 _id], [model1 _id, model2 _id], etc.)
    c)  
6. Allows accessing all models through GET /model/<model _id> ????
7. Creates docs that contain the entire path through (model, modelId) touples (e.g. model2 doc contains (model1, model1 _id) touple and so on)

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

Checks if the implicit model has been created. This check is performed once per session.

    updateModelIdViewIfNeeded = (model, params, callback) ->

        designDocName = getDesignDocName model, params

        internalCallback = (err) ->
            if err
                console.log err
                return kitchen.error.raise 'Unexpected error occurred while updating models', err.statusCode, err

            callback(err, designDocName)

        return internalCallback() if not config.createImplicitViews

        return internalCallback() if not _.isUndefined initializedModels[model]

        designDocId = '_design/' + designDocName

        db.get designDocId, (err, designDoc) ->
            return internalCallback(err) if err && err.statusCode != 404

            design =
                views: {}
            if _.isEmpty params
                throw new Error('not implemented')
                # design.views[viewName] =
                #     map:
                #         'function (doc) {   \
                #             model = doc["' + modelField() + '"];    \
                #             if (model) {    \
                #                 return emit([model, doc.modelId], null);    \
                #             }   \
                #         }'
            else
                models = _.reduce params, (models, modelId, modelName) ->
                    models += ', ' if not _.isEmpty models
                    models += 'doc.' + modelName + ', doc.' + modelName + 'Id'
                , ''
                design.views[viewName] =
                    map:
                        'function (doc) {   \
                            model = doc["' + modelField() + '"];    \
                            if (model === "' + model + '") {    \
                                return emit([' + models + ', doc._id])
                            }   \
                        }'

            # Update the design doc if it has changed or doesn't exist.
            # These conditions avoid rebuilding the view unnecessarily.
            if !designDoc
                designDoc = design
            else
                return internalCallback() if _.isEqual(designDoc.views, design.views)
                designDoc.views = design.views

            db.insert designDoc, designDocId, internalCallback

    getSingle = (model, id, params, callback) ->

        updateModelIdViewIfNeeded model, params, (err, designDocName) ->

            return callback(err) if err

            keyBase = []
            if _.isEmpty params
                keyBase = [model]
            else
                keyBase = [model, params[model]]

            viewParams =
                key: keyBase
                limit: 1
                include_docs: true

            console.log 'viewParams', viewParams, params

            db.view designDocName, viewName, viewParams, (err, result) ->
                return callback(err) if err
                docs = _.map result.rows, (row) -> row.doc
                newNext = undefined
                if viewParams.limit and docs.length == viewParams.limit
                    console.log docs
                    nextDoc = docs.pop()
                    newNext = nextDoc._id
                callback null, docs, newNext


Each model is in a different design document which allows creation/updating to be done separately. If they were in the same doc, all the views would have to be rebuilt every time a single one changed or was added.

    getSet = (model, id, params, next, limit, callback) ->

        updateModelIdViewIfNeeded model, params, (err, designDocName) ->

            return callback(err) if err

            keyBase = []
            if _.isEmpty params
                keyBase = [model]
            else
                keyBase = _.reduce params, (ids, modelId, modelName) ->
                    console.log 'reducing params', ids, modelId, modelName
                    ids.push(modelId)
                    return ids
                , []

            viewParams =
                startkey: if next then keyBase.concat(next) else keyBase
                endkey: keyBase.concat({})
                limit: if limit then parseInt(limit) + 1 else undefined
                include_docs: true

            db.view designDocName, viewName, viewParams, (err, result) ->
                return callback(err) if err
                docs = _.map result.rows, (row) -> row.doc
                newNext = undefined
                if viewParams.limit and docs.length == viewParams.limit
                    console.log docs
                    nextDoc = docs.pop()
                    newNext = nextDoc._id
                callback null, docs, newNext

    post = (model, id, data, params, callback) ->

        doc = _.clone data
        if id
            doc[model + 'Id'] = id
        doc[modelField()] = model
        _.each params, (value, name) ->
            if name != model
                doc[name + 'Id'] = value

        respondCallback = respond(callback)
        db.insert doc, (err, result) ->
            return respondCallback(err) if err or not result
            doc._id = result.id
            doc._rev = result.rev
            respondCallback null, doc

    destroy = (id, rev, callback) ->
        db.destroy id, rev, respond(callback)

## Exported functions

    exports.init = (givenKitchen, driverData) ->
        kitchen = givenKitchen
        config = driverData.config
        nano = require('nano')(config.serverUrl)
        nano.db.create(config.databaseName)
        db = nano.db.use(config.databaseName)

    exports.act = (verb, model, params, query, data, callback) ->

        id = params[model]
        switch verb
            when 'GET', 'HEAD'
                if id
                    getSingle model, id, params, callback
                else
                    getSet model, id, params, query.next, query.limit, callback
            when 'POST' then post model, id, data, params, callback
            when 'DELETE' then destroy id, data._rev, callback
            else callback(new Error('Verb ' + verb + ' is not implemented'))
