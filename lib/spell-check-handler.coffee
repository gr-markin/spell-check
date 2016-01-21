SpellChecker = require 'spellchecker'
multirange = require 'multi-integer-range'

class SpellCheckerHandler
  checkers: []

  addSpellChecker: (spellChecker) ->
    @checkers.push spellChecker

  removeSpellChecker: (spellChecker) ->
    @checkers = @checkers.filter (plugin) -> plugin isnt spellChecker

  check: (id, text) ->
    # For every registered spellchecker, we need to find out the ranges in the
    # text that the checker confirms are correct or indicates is a misspelling.
    # We keep these as separate lists since the different checkers may indicate
    # the same range for either and we need to be able to remove confirmed words
    # from the misspelled ones.
    correct = new multirange.MultiRange([])
    incorrects = []

    for checker in @checkers
      # We only care if this plugin contributes to checking spelling.
      if not checker.isEnabled() or not checker.providesSpelling()
        continue

      # Get the results which includes positive (correct) and negative (incorrect)
      # ranges.
      results = checker.check(text)

      if results.correct
        for range in results.correct
          correct.appendRange(range.start, range.end)

      if results.incorrect
        newIncorrect = new multirange.MultiRange([])
        incorrects.push(newIncorrect)

        for range in results.incorrect
          newIncorrect.appendRange(range.start, range.end)

    # If we don't have any incorrect spellings, then there is nothing to worry
    # about, so just return and stop processing.
    misspellings = []

    if incorrects.length == 0
      return {id, misspellings}

    # Build up an intersection of all the incorrect ranges. We only treat a word
    # as being incorrect if *every* checker that provides negative values treats
    # it as incorrect. We know there are at least one item in this list, so pull
    # that out. If that is the only one, we don't have to do any additional work,
    # otherwise we compare every other one against it, removing any elements
    # that aren't an intersection which (hopefully) will produce a smaller list
    # with each iteration.
    intersection = null
    index = 1

    for incorrect in incorrects
      if intersection is null
        intersection = incorrect
      else
        intersection = @getIntersection(intersection, incorrects[index])

    # If we have no intersection, then nothing to report as a problem.
    if intersection.length is 0
      return {id, misspellings}

    # Remove all of the confirmed correct words from the resulting incorrect
    # list. This allows us to have correct-only providers as opposed to only
    # incorrect providers.
    if correct.ranges.length > 0
      intersection.subtract(correct)

    # Convert the text ranges into Atom buffer coordinates.
    row = 0
    rangeIndex = 0
    characterIndex = 0
    while characterIndex < text.length and rangeIndex < intersection.ranges.length
      lineBreakIndex = text.indexOf('\n', characterIndex)
      if lineBreakIndex is -1
        lineBreakIndex = Infinity

      loop
        range = intersection.ranges[rangeIndex]
        if range and range[0] < lineBreakIndex
          # The range we have here includes whitespace between two concurrent
          # tokens ("zz zz zz" shows up as a single misspelling). The original
          # version would split the example into three separate ones, so we
          # do the same thing.
          @addMisspellings(misspellings, row, range, characterIndex, text)
          rangeIndex++
        else
          break

      characterIndex = lineBreakIndex + 1
      row++

    # Return the resulting misspellings.
    {id, misspellings}

  addMisspellings: (misspellings, row, range, characterIndex, text) ->
    # Get the substring of text, if there is no space, then we can just return
    # the entire result.
    substring = text.substring(range[0], range[1])

    if /\s+/.test substring
      # We have a space, to break it into individual components and push each
      # one to the misspelling list.
      parts = substring.split /(\s+)/
      substringIndex = 0
      for part in parts
        if not /\s+/.test part
          misspellings.push([
            [row, range[0] - characterIndex + substringIndex],
            [row, range[0] - characterIndex + substringIndex + part.length]
          ])
        substringIndex += part.length
      return

    # There were no spaces, so just return the entire list.
    misspellings.push([
      [row, range[0] - characterIndex],
      [row, range[1] - characterIndex]
    ])

  getIntersection: (ranges1, ranges2) ->
    intersection = new multirange.MultiRange([])

    for range1 in ranges1.ranges
      for range2 in ranges2.ranges
        if range1[0] <= range2[1] and range1[1] >= range2[0]
          start = Math.max(range1[0], range2[0])
          end = Math.min(range1[1], range2[1])
          intersection.appendRange(start, end)

    intersection

module.exports = SpellCheckerHandler
