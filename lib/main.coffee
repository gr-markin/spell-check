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
      addKnownWords: atom.config.get('spell-check-test.addKnownWords'),
      checkerPaths: []
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
      @viewsByEditor.set editor, spellCheckView

  deactivate: ->
    @instance?.deactivate()
    @task?.terminate()
    @task = null
    @commandSubscription.dispose()
    @commandSubscription = null
    @disposable.dispose()

  # Registers any Atom packages that provide our service. Because we use a Task,
  # we have to load the plugin's checker in both that service and in the Atom
  # process (for coming up with corrections). Since everything passed to the
  # task must be JSON serialized, we pass the full path to the task and let it
  # require it on that end.
  consumeSpellCheckers: (checkerPaths) ->
    # Normalize it so we always have an array.
    unless checkerPaths instanceof Array
      checkerPaths = [ checkerPaths ]

    # Go through and add any new plugins to the list.
    changed = false
    for checkerPath in checkerPaths
      if checkerPath not in @globalArgs.checkerPaths
        @task?.send {type: "checker", checkerPath: checkerPath}
        @instance?.addCheckerPath checkerPath
        @globalArgs.checkerPaths.push checkerPath

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

      for checkerPath in globalArgs.checkerPath
        @instance.addCheckerPath checkerPath

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
