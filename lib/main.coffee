{Task} = require 'atom'

SpellCheckView = null
spellCheckViews = {}

module.exports =
  activate: ->
    # Set up the task for handling spell-checking in the background. This is
    # what is actually in the background.
    handlerFilename = require.resolve './spell-check-handler'
    @task ?= new Task handlerFilename

    # Since the spell-checking is done on another process, we gather up all the
    # arguments and pass them into the task. Whenever these change, we'll update
    # the object with the parameters and resend it to the task.
    @globalArgs = {
      locales: atom.config.get('spell-check-test.locales'),
      localePaths: atom.config.get('spell-check-test.localePaths'),
      useLocales: atom.config.get('spell-check-test.useLocales'),
      knownWords: atom.config.get('spell-check-test.knownWords'),
      addKnownWords: atom.config.get('spell-check-test.addKnownWords')
    }
    @task.send {type: "global", global: @globalArgs}

    # DREM atom.config.onDidChange 'spell-check-test.locales', ({newValue, oldValue}) ->
    # DREM   @task.args.locales = atom.config.get('spell-check-test.locales')
    # DREM   @task.reloadLocales()
    # DREM   @updateViews()
    # DREM atom.config.onDidChange 'spell-check-test.localePaths', ({newValue, oldValue}) ->
    # DREM   @task.args.localePaths = atom.config.get('spell-check-test.localePaths')
    # DREM   @task.reloadLocales()
    # DREM   @updateViews()
    # DREM atom.config.onDidChange 'spell-check-test.useLocales', ({newValue, oldValue}) ->
    # DREM   @task.args.useLocales = atom.config.get('spell-check-test.useLocales')
    # DREM   @task.reloadLocales()
    # DREM   @updateViews()
    # DREM atom.config.onDidChange 'spell-check-test.knownWords', ({newValue, oldValue}) ->
    # DREM   @task.args.knownWords = atom.config.get('spell-check-test.knownWords')
    # DREM   @task.reloadKnownWords()
    # DREM   @updateViews()
    # DREM atom.config.onDidChange 'spell-check-test.addKnownWords', ({newValue, oldValue}) ->
    # DREM   @task.args.addKnownWords = atom.config.get('spell-check-test.addKnownWords')
    # DREM   @task.reloadKnownWords()
    # DREM   @updateViews()

    # Hook up the UI and processing.
    @commandSubscription = atom.commands.add 'atom-workspace',
        'spell-check-test:toggle': => @toggle()
    @viewsByEditor = new WeakMap
    @disposable = atom.workspace.observeTextEditors (editor) =>
      SpellCheckView ?= require './spell-check-view'

      # The SpellCheckView needs both a handle for the task to handle the
      # background checking and a cached view of the in-process manager for
      # getting corrections. We used a function to a function because scope
      # wasn't working properly.
      spellCheckView = new SpellCheckView(editor, @task, () => @getInstance @globalArgs)

      # save the {editor} into a map
      editorId = editor.id
      spellCheckViews[editorId] = {}
      spellCheckViews[editorId]['view'] = spellCheckView
      spellCheckViews[editorId]['active'] = true
      @viewsByEditor.set(editor, spellCheckView)

  deactivate: ->
    @instance.deactivate()
    @task = null
    @commandSubscription.dispose()
    @commandSubscription = null
    @disposable.dispose()

  consumeSpellCheckers: (plugins) ->
    unless plugins instanceof Array
      plugins = [ plugins ]

    # DREM for plugin in plugins
      # DREM @instance.addPluginChecker plugin

  misspellingMarkersForEditor: (editor) ->
    @viewsByEditor.get(editor).markerLayer.getMarkers()

  updateViews: ->
    for editorId of spellCheckViews
      view = spellCheckViews[editorId]
      if view['active']
        view['view'].updateMisspellings()

  # Retrieves, creating if required, a spelling manager for use with synchronous
  # operations such as retrieving corrections.
  getInstance: (globalArgs) ->
    if not @instance
      SpellCheckerManager = require './spell-check-manager.coffee'
      @instance = SpellCheckerManager
      @instance.setGlobalArgs globalArgs
    return @instance

  # Internal: Toggles the spell-check activation state.
  toggle: ->
    editorId = atom.workspace.getActiveTextEditor().id

    if spellCheckViews[editorId]['active']
      # deactivate spell check for this {editor}
      spellCheckViews[editorId]['active'] = false
      spellCheckViews[editorId]['view'].unsubscribeFromBuffer()
    else
      # activate spell check for this {editor}
      spellCheckViews[editorId]['active'] = true
      spellCheckViews[editorId]['view'].subscribeToBuffer()
