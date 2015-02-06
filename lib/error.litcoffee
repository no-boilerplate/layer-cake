
# Error module

This module is repsonsible for uniform raising of errors throughtout the system.

    _ = require 'lodash'

## Initialization

    exports.init = (kitchen, cake, layer) ->
        kitchen.error = module.exports

## Public functions

### `raise`

`create` will create a new `Error` object with the given `message` and optional `code`. 

    create = (message, code, originalError) ->
        error = new Error(message)
        error.code = code
        error.originalError = originalError if originalError
        return error

    exports.create = create

`raise` will create a new `Error` object with the given `message` and optional `code`. In case that `callback` hasn't been provided the newly created error object will be thrown, otherwise it will be passed as the first parameter to `callback` function which will be invoked asynchronously on `nextTick`.

    raise = (message, code, originalError, callback) ->

        # `originalError` is optional so 3rd argument might actually be callback
        if not callback and _.isFunction originalError
            callback = originalError
            originalError = undefined

        error = create(message, code, originalError)

        if callback and _.isFunction callback
            return process.nextTick ->
                return callback error

        throw error

    exports.raise = raise
