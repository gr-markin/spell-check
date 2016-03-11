class KnownWordsChecker
  enableAdd: false
  spelling: null
  checker: null

  constructor: (knownWords) ->
    # Set up the spelling manager we'll be using.
    spellingManager = require "spelling-manager"
    @spelling = new spellingManager.TokenSpellingManager
    @checker = new spellingManager.BufferSpellingChecker @spelling

    # Set our known words.
    @setKnownWords knownWords

  deactivate: ->
    console.log(@getid() + "deactivating")

  getId: -> "spell-check:known-words"
  getName: -> "Known Words"
  getPriority: -> 10
  isEnabled: -> true
  getStatus: -> "Working correctly."
  providesSpelling: (args) -> true
  providesSuggestions: (args) -> true
  providesAdding: (args) -> @enableAdd

  check: (args, text) ->
    ranges = []
    checked = @checker.check text
    for token in checked
      if token.status == 1
        ranges.push {start: token.start, end: token.end }
    { correct: ranges }

  suggest: (args, word) ->
    @spelling.suggest word

  getAddingTargets: (args) ->
    if @enableAdd
      [{sensitive: false, label: "Add to " + @getName()}]
    else
      []

  add: (args, target) ->
    # Build up the pattern we'll be using. It looks better if we add it not as
    # a regular expression, so figure out how to change this.
    pattern = target.word

    if not target.sensitive
      pattern = pattern.toLowerCase()

    # Add it to the configuration list which will trigger a reload.
    c = atom.config.get 'spell-check-test.knownWords'
    c.push pattern
    atom.config.set 'spell-check-test.knownWords', c

  setAddKnownWords: (newValue) ->
    @enableAdd = newValue

  setKnownWords: (knownWords) ->
    # Clear out the old list.
    @spelling.sensitive = {}
    @spelling.insensitive = {}

    # Add the new ones into the list.
    if knownWords
      for ignore in knownWords
        @spelling.add ignore

module.exports = KnownWordsChecker
