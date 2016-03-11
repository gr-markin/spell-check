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
    # Build up the arguments object for this buffer and text.
    projectPath = null
    relativePath = null
    if buffer?.file?.path
      [projectPath, relativePath] = atom.project.relativizePath(buffer.file.path)
    args = {
      id: @id,
      projectPath: projectPath,
      relativePath: relativePath
    }

    # Dispatch the request.
    @constructor.dispatchMisspellings @handler.check(args, buffer.getText())

  onDidSpellCheck: (callback) ->
    @constructor.callbacksById[@id] = callback

  @dispatchMisspellings: ({id, misspellings}) =>
    @callbacksById[id]?(misspellings)
