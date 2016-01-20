SpellChecker = require 'spellchecker'

class SpellCheckerHandler
  spellCheckers: []

  addSpellChecker: (spellChecker) ->
    @spellCheckers.push spellChecker

  deleteSpellChecker: (spellChecker) ->
    @spellCheckers = @spellCheckers.filter (plugin) -> plugin isnt spellChecker

  check: (id, text) ->
    # For every spellchecker, build up a list of misspellings, and convert them into
    # editor-specific coordinates. At the same time, we also build up a count of how many
    # checkers feel that a word is a misspelling because all checkers have to agree that a
    # word is misspelled before we identify it as such.
    potentials = []
    for checker in @spellCheckers
      # Get the misspelled range from the checker.
      misspelledCharacterRanges = checker.getMispelledRanges(text)

      # Convert the text ranges into Atom buffer coordinates.
      row = 0
      rangeIndex = 0
      characterIndex = 0
      while characterIndex < text.length and rangeIndex < misspelledCharacterRanges.length
        lineBreakIndex = text.indexOf('\n', characterIndex)
        if lineBreakIndex is -1
          lineBreakIndex = Infinity

        loop
          range = misspelledCharacterRanges[rangeIndex]
          if range and range.start < lineBreakIndex
            # Build up the start of the elements and then figure out a key to
            # see if this range has already been seen.
            lineStart = range.start - characterIndex
            lineEnd = range.end - characterIndex
            key = row + " " + lineStart + " " + lineEnd;

            if potentials.hasOwnProperty(key)
              # Already exists, so increment the references.
              potentials[key].count += 1
            else
              # It's a new range, so add it to the list.
              potentials[key] = {count: 1, range: [[row, lineStart], [row, lineEnd]]}

            rangeIndex++
          else
            break

        characterIndex = lineBreakIndex + 1
        row++

    # Go through the list of potential misspellings and keep the ones that all
    # checkers agree are misspelling. If they are, add to the misspellings before
    # returning the results.
    misspellings = []
    for key of potentials
      range = potentials[key]
      if range.count == @spellCheckers.length
        misspellings.push(range.range)

    # Return the resulting misspellings.
    {id, misspellings}

module.exports = SpellCheckerHandler
