{Task} = require 'atom'
idCounter = 0

# Wraps a single {Task} so that multiple views reuse the same task but it is
# terminated once all views are removed.
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

  start: (text) ->
    #@constructor.task ?= new Task(@handler.check)
    #@constructor.task?.start {@id, text}, @constructor.dispatchMisspellings
    console.log("test", @handler, @id)
    @constructor.dispatchMisspellings(@handler.check(@id, text))
    console.log("nope")

  onDidSpellCheck: (callback) ->
    @constructor.callbacksById[@id] = callback

  @dispatchMisspellings: ({id, misspellings}) =>
    @callbacksById[id]?(misspellings)
