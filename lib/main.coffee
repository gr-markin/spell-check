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
      description: 'List of locales to use for the system spell-checking. Examples would be "en-US" or "de-DE".'
      order: 3
    localePaths:
      type: 'array'
      default: [
        '/usr/share/hunspell',
        '/usr/share/myspell/dicts'
      ]
      items:
        type: 'string'
      description: 'List of paths to search for dictionary files. "internal" is a special case of using the dictionary shipped with the internal NodeJS modules.'
      order: 4
    personalDictionary:
      type: 'string'
      default: ''
      description: 'If a path is provided, then a personal dictionary will be use that allows for checking and adding new words. If a directory is given, a file named `personal.dic` will be created.'
      order: 7
    ignoreWords:
      type: 'array'
      default: [
        'GitHub',
        '/github/'
      ]
      description: 'List words that are considered correct even if they do not appear in any other dictionary.'
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
    @ignore = new IgnoreChecker ignoreWords
    @instance.addSpellChecker @ignore

    atom.config.onDidChange 'spell-check.ignoreWords', ({newValue, oldValue}) ->
      that.ignore.setIgnoreWords newValue

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
