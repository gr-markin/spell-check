SystemChecker = require "./system-checker"
SpellCheckView = null
spellCheckViews = {}

module.exports =
  instance: null
  ignore: null
  localeDictionaries: []

  activate: ->
    # Create the unified handler for all spellchecking.
    SpellCheckerHandler = require './spell-check-handler.coffee'
    @instance = new SpellCheckerHandler

    # Initialize the system dictionaries and listen to any changes.
    that = this
    that.reloadLocaleDictionaries atom.config.get('spell-check-test.locales')
    atom.config.onDidChange 'spell-check-test.locales', ({newValue, oldValue}) ->
      that.reloadLocaleDictionaries atom.config.get('spell-check-test.locales')
    atom.config.onDidChange 'spell-check-test.localePaths', ({newValue, oldValue}) ->
      that.reloadLocaleDictionaries atom.config.get('spell-check-test.locales')
    atom.config.onDidChange 'spell-check-test.useLocales', ({newValue, oldValue}) ->
      that.reloadLocaleDictionaries atom.config.get('spell-check-test.locales')

    # Add in the ignore dictionary.
    IgnoreChecker = require './ignore-checker.coffee'
    knownWords = atom.config.get('spell-check-test.knownWords')
    addKnownWords = atom.config.get('spell-check-test.addKnownWords')
    @ignore = new IgnoreChecker knownWords
    @ignore.setAddKnownWords addKnownWords
    @instance.addSpellChecker @ignore

    atom.config.onDidChange 'spell-check-test.knownWords', ({newValue, oldValue}) ->
      that.ignore.setKnownWords newValue
    atom.config.onDidChange 'spell-check-test.addKnownWords', ({newValue, oldValue}) ->
      that.ignore.setAddKnownWords newValue

    @commandSubscription = atom.commands.add 'atom-workspace',
        'spell-check-test:toggle': => @toggle()
    @viewsByEditor = new WeakMap
    @disposable = atom.workspace.observeTextEditors (editor) =>
      SpellCheckView ?= require './spell-check-view'
      spellCheckView = new SpellCheckView(editor, @instance)

      # save the {editor} into a map
      editorId = editor.id
      spellCheckViews[editorId] = {}
      spellCheckViews[editorId]['view'] = spellCheckView
      spellCheckViews[editorId]['active'] = true
      @viewsByEditor.set(editor, spellCheckView)

  misspellingMarkersForEditor: (editor) ->
    @viewsByEditor.get(editor).markerLayer.getMarkers()

  deactivate: ->
    @commandSubscription.dispose()
    @commandSubscription = null
    @disposable.dispose()

  consumeSpellCheckers: (plugins) ->
    unless plugins instanceof Array
      plugins = [ plugins ]

    for plugin in plugins
      @instance.addSpellChecker(plugin)

    #new Disposable =>
    #  for plugin in plugins
    #    @instance.addSpellChecker(plugin)

  reloadLocaleDictionaries: (locales) ->
    console.log 'spell-check: reloading locale dictionaries', locales

    # Remove any old dictionaries from the list.
    for dict in @localeDictionaries
      @instance.removeSpellChecker dict
    @localeDictionaries.clear

    # If we aren't using the locales, then skip it.
    useLocales = atom.config.get 'spell-check-test.useLocales'
    if not useLocales
      return

    # Go through the new list and create new ones.
    paths = atom.config.get 'spell-check-test.localePaths'
    for locale in locales
      checker = new SystemChecker locale, paths
      @instance.addSpellChecker checker
      @localeDictionaries.push checker

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
