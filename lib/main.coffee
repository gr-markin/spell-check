SpellCheckView = null

module.exports =
  instance: null

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
      description: 'List of scopes for languages which will be checked for misspellings. See [the README](https://github.com/atom/spell-check#spell-check-package-) for more information on finding the correct scope for a specific language.'

  activate: ->
    # Create the unified handler for all spellchecking.
    SpellCheckerHandler = require './spell-check-handler.coffee'
    @instance = new SpellCheckerHandler

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
