spellchecker = require 'spellchecker'

class Checker
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

  getId: ->
    "spell-check-" + @locale.toLowerCase().replace("_", "-")

  isEnabled: ->
    @enabled

  deactivate: ->
    console.log("deactivating en-us")

  checkSpelling: (text) ->
    { incorrect: @spellchecker.checkSpelling(text) }

  getMispelledRanges: (text) ->
    @spellchecker.checkSpelling(text)

module.exports = Checker
