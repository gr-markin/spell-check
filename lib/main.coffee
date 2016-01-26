SystemChecker = require "./system-checker"
SpellCheckView = null

module.exports =
  config:
    grammars:
      type: 'array'
      default: [
        'source.asciidoc'
        'source.gfm'
        'text.git-commit'
        'text.plain'
        'text.plain.null-grammar'
      ]
      items:
        type: 'string'
      description: 'List of scopes for languages which will be checked for misspellings. See [the README](https://github.com/atom/spell-check#spell-check-package-) for more information on finding the correct scope for a specific language.'
      order: 1
    useLocales:
      type: 'boolean'
      default: true
      description: 'If unchecked, then the locales below will not be used for spell-checking.'
      order: 2
    locales:
      type: 'array'
      default: [
        navigator.language
      ]
      items:
        type: 'string'
      description: 'List of locales to use for the system spell-checking. Examples would be "en-US" or "de-DE". For Windows, the appropriate language must be installed and Atom restarted.'
      order: 3
    localePaths:
      type: 'array'
      default: []
      items:
        type: 'string'
      description: 'List of additional paths to search for dictionary files. If a locale cannot be found in these, the internal code will attempt to find it using common search paths.'
      order: 4
    ignoreWords:
      type: 'array'
      default: []
      description: 'List words that are considered correct even if they do not appear in any other dictionary.'
      order: 7
    addIgnoreWords:
      type: 'boolean'
      default: false
      description: 'If checked, then the suggestions will include options to add to the ignore words list.'
      order: 8

  instance: null
  ignore: null
  localeDictionaries: []

  activate: ->
    # Create the unified handler for all spellchecking.
    SpellCheckerHandler = require './spell-check-handler.coffee'
    @instance = new SpellCheckerHandler

    # Initialize the system dictionaries and listen to any changes.
    that = this
    that.reloadLocaleDictionaries atom.config.get('spell-check.locales')
    atom.config.onDidChange 'spell-check.locales', ({newValue, oldValue}) ->
      that.reloadLocaleDictionaries atom.config.get('spell-check.locales')
    atom.config.onDidChange 'spell-check.localePaths', ({newValue, oldValue}) ->
      that.reloadLocaleDictionaries atom.config.get('spell-check.locales')
    atom.config.onDidChange 'spell-check.useLocales', ({newValue, oldValue}) ->
      that.reloadLocaleDictionaries atom.config.get('spell-check.locales')

    # Add in the ignore dictionary.
    IgnoreChecker = require './ignore-checker.coffee'
    ignoreWords = atom.config.get('spell-check.ignoreWords')
    addIgnoreWords = atom.config.get('spell-check.addIgnoreWords')
    @ignore = new IgnoreChecker ignoreWords
    @ignore.setAddIgnoreWords addIgnoreWords
    @instance.addSpellChecker @ignore

    atom.config.onDidChange 'spell-check.ignoreWords', ({newValue, oldValue}) ->
      that.ignore.setIgnoreWords newValue
    atom.config.onDidChange 'spell-check.addIgnoreWords', ({newValue, oldValue}) ->
      that.ignore.setAddIgnoreWords newValue

    # Set up the linkage to all the views that need checking.
    @viewsByEditor = new WeakMap
    @disposable = atom.workspace.observeTextEditors (editor) =>
      SpellCheckView ?= require './spell-check-view'
      @viewsByEditor.set(editor, new SpellCheckView(editor, @instance))

  misspellingMarkersForEditor: (editor) ->
    @viewsByEditor.get(editor).markerLayer.getMarkers()

  deactivate: ->
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
    useLocales = atom.config.get 'spell-check.useLocales'
    if not useLocales
      return

    # Go through the new list and create new ones.
    paths = atom.config.get 'spell-check.localePaths'
    for locale in locales
      checker = new SystemChecker locale, paths
      @instance.addSpellChecker checker
      @localeDictionaries.push checker
