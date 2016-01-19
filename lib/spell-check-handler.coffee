SpellChecker = require 'spellchecker'

class SpellCheckerHandler
  spellCheckers: []

  addSpellChecker: (spellChecker) ->
      @spellCheckers.push spellChecker

  deleteSpellChecker: (spellChecker) ->
      @spellCheckers = @spellCheckers.filter (plugin) -> plugin isnt spellChecker

  check: ({id, text}) ->
    # TODO misspelledCharacterRanges = SpellChecker.checkSpelling(text)
    console.log("initializing spellchecker")

    # TODO row = 0
    # TODO rangeIndex = 0
    # TODO characterIndex = 0
    misspellings = []
    # TODO while characterIndex < text.length and rangeIndex < misspelledCharacterRanges.length
    # TODO   lineBreakIndex = text.indexOf('\n', characterIndex)
    # TODO   if lineBreakIndex is -1
    # TODO     lineBreakIndex = Infinity

    # TODO   loop
    # TODO     range = misspelledCharacterRanges[rangeIndex]
    # TODO     if range and range.start < lineBreakIndex
    # TODO       misspellings.push([
    # TODO         [row, range.start - characterIndex],
    # TODO         [row, range.end - characterIndex]
    # TODO       ])
    # TODO       rangeIndex++
    # TODO     else
    # TODO       break

    # TODO   characterIndex = lineBreakIndex + 1
    # TODO   row++

    {id, misspellings}

module.exports = SpellCheckerHandler
