idCounter = 0

module.exports =
class SpellCheckTask
  @handler: null
  @callbacksById: {}

  constructor: (handler) ->
    @id = idCounter++
    @handler = handler

  terminate: ->
    delete @constructor.callbacksById[@id]

    if Object.keys(@constructor.callbacksById).length is 0
      @constructor.task?.terminate()
      @constructor.task = null

  start: (buffer) ->
    @constructor.dispatchMisspellings @handler.check(@id, buffer)

  onDidSpellCheck: (callback) ->
    @constructor.callbacksById[@id] = callback

  @dispatchMisspellings: ({id, misspellings}) =>
    @callbacksById[id]?(misspellings)
