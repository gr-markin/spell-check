The original system deleted the tasks when there were no more views. In this
case, we want the plugin the manage the lifecycle of the task, not the views so
we removed this from the constructor.

    if Object.keys(@constructor.callbacksById).length is 0
      @constructor.task?.terminate()
      @constructor.task = null

* Change to be word-based searching.
* Plugins sending responses/changes to the task.

# We need a couple packages.
multirange = require 'multi-integer-range'

# For every registered spellchecker, we need to find out the ranges in the
# text that the checker confirms are correct or indicates is a misspelling.
# We keep these as separate lists since the different checkers may indicate
# the same range for either and we need to be able to remove confirmed words
# from the misspelled ones.
correct = new multirange.MultiRange([])
incorrects = []

for checker in @checkers
  # We only care if this plugin contributes to checking spelling.
  if not checker.isEnabled() or not checker.providesSpelling(args)
    continue

  # Get the results which includes positive (correct) and negative (incorrect)
  # ranges.
  results = checker.check(args, text)

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

if incorrects.length is 0
  return {id: args.id, misspellings}

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
    intersection.intersect(incorrects[index])

# If we have no intersection, then nothing to report as a problem.
if intersection.length is 0
  return {id: args.id, misspellings}

# Remove all of the confirmed correct words from the resulting incorrect
# list. This allows us to have correct-only providers as opposed to only
# incorrect providers.
if correct.ranges.length > 0
  intersection.subtract(correct)

-- subscribeToBuffer

range = intersection.ranges[rangeIndex]
if range and range[0] < lineEndIndex
  # Figure out the character range of this line. We need this because
  # @addMisspellings doesn't handle jumping across lines easily and the
  # use of the number ranges is inclusive.
  lineRange = new multirange.MultiRange([]).appendRange(lineBeginIndex, lineEndIndex)
  rangeRange = new multirange.MultiRange([]).appendRange(range[0], range[1])
  lineRange.intersect(rangeRange)

  # The range we have here includes whitespace between two concurrent
  # tokens ("zz zz zz" shows up as a single misspelling). The original
  # version would split the example into three separate ones, so we
  # do the same thing, but only for the ranges within the line.
  @addMisspellings(misspellings, row, lineRange.ranges[0], lineBeginIndex, text)

  # If this line is beyond the limits of our current range, we move to
  # the next one, otherwise we loop again to reuse this range against
  # the next line.
  if lineEndIndex >= range[1]
    rangeIndex++
  else
    break
else
  break

lineBeginIndex = lineEndIndex + 1
row++
