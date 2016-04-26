{Task} = require 'atom'
idCounter = 0

module.exports =
class SpellCheckTask
  @handler: null
  @callbacksById: {}

  constructor: ->
    @id = idCounter++
    @args = {}

  terminate: ->
    delete @constructor.callbacksById[@id]

    if Object.keys(@constructor.callbacksById).length is 0
      @constructor.task?.terminate()
      @constructor.task = null

  start: (buffer) ->
    # Figure out the paths since we need that for checkers that are project-specific.
    projectPath = null
    relativePath = null
    if buffer?.file?.path
      [projectPath, relativePath] = atom.project.relativizePath(buffer.file.path)

    # NOTASK # We also need to pull out the spelling manager to we can grab fields from that.
    # NOTASK instance = require('./spell-check-manager')

    # Create an arguments that passes everything over. Since tasks are run in a
    # separate background process, they can't use the initialized values from
    # our instance and buffer. We also can't pass complex items across since
    # they are serialized as JSON.
    text = buffer.getText()

    # Set up the task for handling spell-checking in the background. This is
    # what is actually in the background.
    handlerFilename = require.resolve './spell-check-handler'
    @constructor.task ?= new Task handlerFilename
    @constructor.task?.start {@id, @args, text}, @constructor.dispatchMisspellings

  onDidSpellCheck: (callback) ->
    @constructor.callbacksById[@id] = callback

  @dispatchMisspellings: (data) =>
    console.log "dispatchMispellings", data
    @callbacksById[data.id]?(data.misspellings)
