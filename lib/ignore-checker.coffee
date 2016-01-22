class IgnoreChecker
  ignores: []

  constructor: (ignoreWords) ->
    @setIgnoreWords ignoreWords

  deactivate: ->
    console.log("deactivating " + @getId())

  getId: -> "spell-check:ignore"
  getName: -> "Ignore Words"
  getPriority: -> 10
  isEnabled: -> true
  getStatus: -> "Working correctly."
  providesSpelling: (buffer) -> true
  providesSuggestions: (buffer) -> true
  providesAdding: (buffer) -> false

  check: (buffer, text) ->
    ranges = []
    for ignore in @ignores
      textIndex = 0
      input = text
      while textIndex < text.length
        # See if the current string has a match against the regex.
        m = input.match ignore.regex
        if not m
          break
        ranges.push {start: m.index + textIndex, end: m.index + textIndex + m[0].length }
        textIndex += m.index + textIndex + m[0].length
        input = input.substring (m.index + m[0].length)
    { correct: ranges }

  suggest: (buffer, word) ->
    natural = require "natural"

    # Gather up all the words that are within a given distance.
    s = []
    for ignore in @ignores
      distance = natural.JaroWinklerDistance word, ignore.text
      if distance >= 0.9
        s.push { text: ignore.text, distance: distance }

    # Sort the results based on distance.
    keys = Object.keys(s).sort (key1, key2) ->
      value1 = s[key1]
      value2 = s[key2]
      if value1.distance != value2.distance
        return value1.distance - value2.distance
      return value1.text.localeCompare(value2.text)

    # Use the resulting keys to build up a list.
    results = []
    for key in keys
      results.push s[key].text
    results

  setIgnoreWords: (ignoreWords) ->
    @ignores = []
    if ignoreWords
      for ignore in ignoreWords
        @ignores.push @makeIgnore ignore
    console.log("spell-check: ignore words ", @ignores)

  makeIgnore: (input) ->
    m = input.match /^\/(.*)\/(\w*)$/
    if m
      # Build up the regex from the components. We can't handle "g" in the flags,
      # so quietly remove it.
      f = m[2].replace("g", "")
      r = new RegExp m[1], f
      { regex: r, text: m[1], flags: f }
    else
      # We want a case-insensitive search only if the input is in all lowercase.
      # We also use word boundaries as part of the search when they don't give
      # us terminators.
      f = ""
      if input is input.toLowerCase()
        f = "i"
      r = new RegExp ("\\b" + input + "\\b"), f
      { regex: r, text: input, flags: f }

module.exports = IgnoreChecker
