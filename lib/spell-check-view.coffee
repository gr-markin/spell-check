_ = require 'underscore-plus'
{CompositeDisposable} = require 'atom'
SpellCheckTask = require './spell-check-task'

CorrectionsView = null
SpellChecker = null

module.exports =
class SpellCheckView
  @content: ->
    @div class: 'spell-check-test'

  constructor: (@editor, @handler) ->
    @disposables = new CompositeDisposable
    @task = new SpellCheckTask(@handler)
    @initializeMarkerLayer()

    @correctMisspellingCommand = atom.commands.add atom.views.getView(@editor), 'spell-check-test:correct-misspelling', =>
      if marker = @markerLayer.findMarkers({containsPoint: @editor.getCursorBufferPosition()})[0]
        CorrectionsView ?= require './corrections-view'
        @correctionsView?.destroy()
        @correctionsView = new CorrectionsView(@editor, @getCorrections(marker), marker)

    @task.onDidSpellCheck (misspellings) =>
      @detroyMarkers()
      @addMarkers(misspellings) if @buffer?

    @disposables.add @editor.onDidChangePath =>
      @subscribeToBuffer()

    @disposables.add @editor.onDidChangeGrammar =>
      @subscribeToBuffer()

    @disposables.add atom.config.onDidChange 'editor.fontSize', =>
      @subscribeToBuffer()

    @disposables.add atom.config.onDidChange 'spell-check-test.grammars', =>
      @subscribeToBuffer()

    @subscribeToBuffer()

    @disposables.add @editor.onDidDestroy(@destroy.bind(this))

  initializeMarkerLayer: ->
    @markerLayer = @editor.getBuffer().addMarkerLayer()
    @markerLayerDecoration = @editor.decorateMarkerLayer(@markerLayer, {
      type: 'highlight',
      class: 'spell-check-test-misspelling',
      deprecatedRegionClass: 'misspelling'
    })

  destroy: ->
    @unsubscribeFromBuffer()
    @disposables.dispose()
    @task.terminate()
    @markerLayer.destroy()
    @markerLayerDecoration.destroy()
    @correctMisspellingCommand.dispose()
    @correctionsView?.remove()

  unsubscribeFromBuffer: ->
    @detroyMarkers()

    if @buffer?
      @bufferDisposable.dispose()
      @buffer = null

  subscribeToBuffer: ->
    @unsubscribeFromBuffer()

    if @spellCheckCurrentGrammar()
      @buffer = @editor.getBuffer()
      @bufferDisposable = @buffer.onDidStopChanging => @updateMisspellings()
      @updateMisspellings()

  spellCheckCurrentGrammar: ->
    grammar = @editor.getGrammar().scopeName
    _.contains(atom.config.get('spell-check-test.grammars'), grammar)

  detroyMarkers: ->
    @markerLayer.destroy()
    @markerLayerDecoration.destroy()
    @initializeMarkerLayer()

  addMarkers: (misspellings) ->
    for misspelling in misspellings
      @markerLayer.markRange(misspelling,
        invalidate: 'touch',
        replicate: 'false',
        persistent: false,
        maintainHistory: false,
      )

  updateMisspellings: ->
    # Task::start can throw errors atom/atom#3326
    try
      @task.start(@buffer)
    catch error
      console.warn('Error starting spell check task', error.stack ? error)

  getCorrections: (marker) ->
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

    # Get the misspelled word and then request corrections.
    misspelling = @editor.getTextInBufferRange(marker.getRange())
    corrections = @handler.suggest(@buffer, misspelling)
