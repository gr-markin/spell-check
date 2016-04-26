SpellCheckView = null
spellCheckViews = {}

module.exports =
  task: null

  activate: ->
    # Create the unified task wrapper which is used for all checking.
    SpellCheckTask = require './spell-check-task.coffee'
    @task = new SpellCheckTask

    # Initialize the spelling manager so it can perform deferred loading.
    @task.args.locales = atom.config.get('spell-check-test.locales')
    @task.args.localePaths = atom.config.get('spell-check-test.localePaths')
    @task.args.useLocales = atom.config.get('spell-check-test.useLocales')

    atom.config.onDidChange 'spell-check-test.locales', ({newValue, oldValue}) ->
      @task.args.locales = atom.config.get('spell-check-test.locales')
      @task.reloadLocales()
      @updateViews()
    atom.config.onDidChange 'spell-check-test.localePaths', ({newValue, oldValue}) ->
      @task.args.localePaths = atom.config.get('spell-check-test.localePaths')
      @task.reloadLocales()
      @updateViews()
    atom.config.onDidChange 'spell-check-test.useLocales', ({newValue, oldValue}) ->
      @task.args.useLocales = atom.config.get('spell-check-test.useLocales')
      @task.reloadLocales()
      @updateViews()

    # Add in the settings for known words checker.
    @task.args.knownWords = atom.config.get('spell-check-test.knownWords')
    @task.args.addKnownWords = atom.config.get('spell-check-test.addKnownWords')

    atom.config.onDidChange 'spell-check-test.knownWords', ({newValue, oldValue}) ->
      @task.args.knownWords = atom.config.get('spell-check-test.knownWords')
      @task.reloadKnownWords()
      @updateViews()
    atom.config.onDidChange 'spell-check-test.addKnownWords', ({newValue, oldValue}) ->
      @task.args.addKnownWords = atom.config.get('spell-check-test.addKnownWords')
      @task.reloadKnownWords()
      @updateViews()

    # Hook up the UI and processing.
    @commandSubscription = atom.commands.add 'atom-workspace',
        'spell-check-test:toggle': => @toggle()
    @viewsByEditor = new WeakMap
    @disposable = atom.workspace.observeTextEditors (editor) =>
      SpellCheckView ?= require './spell-check-view'
      spellCheckView = new SpellCheckView(editor, @task)

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
