spellchecker = require 'spellchecker'

class SystemChecker
  spellchecker: null
  locale: null
  enabled: true
  reason: null

  constructor: (locale, paths) ->
    @spellchecker = new spellchecker.Spellchecker
    @locale = locale

    # We have to check both the dash (en-US) and the unscore (en_US) because
    # Windows 8 uses one, Linux uses another. We also check every given path
    # provided by the parameters.
    for path in paths
      if @spellchecker.setDictionary(locale, path)
        return

    # If we broke out of the loop, we couldn't load the checker.
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

  suggest: (buffer, word) -> [] # TODO Not implemented yet.

module.exports = SystemChecker
