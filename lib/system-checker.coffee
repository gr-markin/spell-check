spellchecker = require 'spellchecker'

class Checker
  spellchecker: null
  locale: null
  disabled: false
  reason: null

  constructor: (locale, paths) ->
    @spellchecker = new spellchecker.Spellchecker
    @locale = locale

    # We have to check both the dash (en-US) and the unscore (en_US) because
    # Windows 8 uses one, Linux uses another. We also check every given path
    # provided by the parameters.
    for path in paths
      # If we have "internal" as a path, use the dictionary's paths.
      if path is "internal"
        path = spellchecker.getDictionaryPath

      if @spellchecker.setDictionary(locale, "/usr/share/hunspell/")
        return

    # If we broke out of the loop, we couldn't load the checker.
    @disabled = true
    @reason = "Cannot find dictionary for " + @locale + "."
    console.log @locale, @reason

  getId: ->
    "spell-check-" + @locale.toLowerCase().replace("_", "-")

  deactivate: ->
    console.log("deactivating en-us")

  checkSpelling: (text) ->
    { incorrect: @spellchecker.checkSpelling(text) }

  getMispelledRanges: (text) ->
    @spellchecker.checkSpelling(text)

module.exports = Checker
