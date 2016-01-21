class IgnoreChecker
  ignoreRegexes: []

  constructor: (ignoreWords) ->
    @setIgnoreWords ignoreWords

  deactivate: ->
    console.log("deactivating " + @getId())

  getId: -> "spell-check:ignore"
  getName: -> "Ignore Words"
  getPriority: -> 10
  isEnabled: -> true
  getStatus: -> "Working correctly."
  providesSpelling: -> true
  providesSuggestions: -> false
  providesAdding: -> false

  check: (text) ->
    ranges = []
    for ignoreRegex in @ignoreWords
      textIndex = 0
      input = text
      while textIndex < text.length
        # See if the current string has a match against the regex.
        m = input.match ignoreRegex
        if not m
          break
        ranges.push {start: m.index + textIndex, end: m.index + textIndex + m[0].length }
        textIndex += m.index + textIndex + m[0].length
        input = input.substring (m.index + m[0].length)
    { correct: ranges }

  setIgnoreWords: (ignoreWords) ->
    @ignoreWords = []
    if ignoreWords
      for ignore in ignoreWords
        @ignoreWords.push @makeRegex ignore
    console.log("spell-check: ignore words ", @ignoreWords)

  makeRegex: (input) ->
    m = input.match /^\/(.*)\/(\w*)$/
    if m
      # Build up the regex from the components. We can't handle "g" in the flags,
      # so quietly remove it.
      new RegExp m[1], m[2].replace("g", "")
    else
      # We want a case-insensitive search only if the input is in all lowercase.
      # We also use word boundaries as part of the search when they don't give
      # us terminators.
      flag = ""
      if input is input.toLowerCase()
        flag = "i"
      new RegExp ("\\b" + input + "\\b"), flag

module.exports = IgnoreChecker
