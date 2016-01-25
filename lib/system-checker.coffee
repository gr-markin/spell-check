spellchecker = require 'spellchecker'
path = require 'path'

class SystemChecker
  spellchecker: null
  locale: null
  enabled: true
  reason: null

  constructor: (locale, paths) ->
    @spellchecker = new spellchecker.Spellchecker
    @locale = locale

    # Check the paths supplied by the user.
    for path in paths
      if @spellchecker.setDictionary locale, path
        return

    # Check common locations for the dictionary. These locations are based on
    # the operating system.
    if /linux/.test process.platform
      if @spellchecker.setDictionary locale, "/usr/share/hunspell"
        return
      if @spellchecker.setDictionary locale, "/usr/share/myspell/dicts"
        return

    if /win32/.test process.platform
      if @spellchecker.setDictionary locale, "C:\\Program Files (x86)\\Mozilla Firefox\\dictionaries"
        return

    # Try the packaged library inside the node_modules. `getDictionaryPath` is
    # not available, so we have to fake it. This will only work for en-US.
    vendor = path.join __dirname, "..", "node_modules", "spellchecker", "vendor", "hunspell_dictionaries"
    if @spellchecker.setDictionary locale, vendor
      return

    # If we fell through all the if blocks, then we couldn't load the dictionary.
    @enabled = false
    @reason = "Cannot find dictionary for " + @locale + "."
    console.log @locale, @reason

  deactivate: ->
    console.log("deactivating " + @getId())

  getId: -> "spell-check:" + @locale.toLowerCase().replace("_", "-")
  getName: -> "System Dictionary (" + @locale + ")"
  getPriority: -> 100 # System level data, has no user input.
  isEnabled: -> @enabled
  getStatus: ->
    if @enabled
      "Working correctly."
    else
      @reason

  providesSpelling: (buffer) -> true
  providesSuggestions: (buffer) -> true
  providesAdding: (buffer) -> false # Users shouldn't be adding to the system dictionary.

  check: (buffer, text) ->
    { incorrect: @spellchecker.checkSpelling(text) }

  suggest: (buffer, word) ->
    @spellchecker.getCorrectionsForMisspelling(word)

module.exports = SystemChecker
