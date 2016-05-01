class SpellCheckerManager
  checkers: []
  checkerPaths: []
  locales: []
  localePaths: []
  useLocales: false
  localeCheckers: null
  knownWords: []
  addKnownWords: false
  knownWordsChecker: null

  setGlobalArgs: (data) ->
    # We need underscore to do the array comparisons.
    _ = require "underscore-plus"

    # Check to see if any values have changed. When they have, they clear out
    # the applicable checker which forces a reload.
    changed = false
    removeLocaleCheckers = false
    removeKnownWordsChecker = false

    if not _.isEqual(@locales, data.locales)
      # If the locales is blank, then we always create a default one. However,
      # any new data.locales will remain blank.
      if not @localeCheckers or data.locales?.length isnt 0
        @locales = data.locales
        removeLocaleCheckers = true
    if not _.isEqual(@localePaths, data.localePaths)
      @localePaths = data.localePaths
      removeLocaleCheckers = true
    if @useLocales isnt data.useLocales
      @useLocales = data.useLocales
      removeLocaleCheckers = true
    if @knownWords isnt data.knownWords
      @knownWords = data.knownWords
      removeKnownWordsChecker = true
      changed = true
    if @addKnownWords isnt data.addKnownWords
      @addKnownWords = data.addKnownWords
      removeKnownWordsChecker = true
      # We don't update `changed` since it doesn't affect the plugins.

    # If we made a change to the checkers, we need to remove them from the
    # system so they can be reinitialized.
    if removeLocaleCheckers and @localeCheckers
      checkers = @localeCheckers
      for checker in checkers
        @removeSpellChecker @checker
      @localeCheckers = null
      changed = true

    if removeKnownWordsChecker and @knownWordsChecker
      @removeSpellChecker @knownWordsChecker
      @knownWordsChecker = null
      changed = true

    # If we had any change to the system, we need to send a message back to the
    # main process so it can trigger a recheck which then calls `init` which
    # then locales any changed locales or known words checker.
    if changed
      @emitSettingsChanged()

  emitSettingsChanged: ->
    console.log "sending change"
    emit("spell-check-test:settings-changed")

  addCheckerPath: (checkerPath) ->
    checker = require checkerPath
    console.log "spell-check-test: addCheckerPath:", checkerPath, checker
    @addPluginChecker checker

  addPluginChecker: (checker) ->
    # Add the spell checker to the list.
    @addSpellChecker checker

    # We only emit a settings change for plugins since the core checkers are
    # handled in a different manner.
    @emitSettingsChanged()

  addSpellChecker: (checker) ->
    console.log "spell-check-test: addSpellChecker:", checker
    @checkers.push checker

  removeSpellChecker: (spellChecker) ->
    @checkers = @checkers.filter (plugin) -> plugin isnt spellChecker

  check: (args, text) ->
    # Make sure our deferred initialization is done.
    @init()

    # Unfortunately, the version of Javascript that Atom uses doesn't really
    # play well with Unicode characters. This means we can't use `\w+` to cover
    # all the characters. Instead, we have to use a convoluted method until
    # Chromium and Atom learn how to work with Unicode. The range here is to
    # cover a "reasonable" range of characters including some accented ones.
    wRegexClass = '[\\w\\u0080-\\u00FF\\u0100-\\u017F\\u0180-\\u024F]'
    wRegexPattern = '(' + wRegexClass + '+(?:\'' + wRegexClass + '+)?)'
    wRegex = new RegExp wRegexPattern

    # Splitting apart a line into words can be somewhat difficult and language-
    # dependent. Until we have the ability to have a language-specific setting
    # or services, we use a generic method.
    natural = require "natural"
    tokenizer = new natural.RegexpTokenizer { pattern: wRegex }

    # We have a small local cache here. Because of how the checkers work today,
    # if "baz" is wrong in one place, it will be wrong in the entire document.
    # Likewise, English and most other languages has a lot of redundancy with
    # pronouns, articles, and the like that if we don't have to call the checker
    # then we will be more performant. We keep the cache locale to a single
    # buffer call so we don't have to worry about invalidation.
    cache = {}

    # Because we check individual words, we can do this on a line-by-line basis
    # and keep the coordinate processing relatively simple since ranges are
    # given as character indexes within a given line. This loop goes through the
    # the input and processes each line individually.
    row = 0
    lineBeginIndex = 0
    misspellings = []

    while lineBeginIndex < text.length
      # Figure out where the next line break is. If we hit -1, then we make sure
      # it is a higher number so our < comparisons work properly.
      lineEndIndex = text.indexOf('\n', lineBeginIndex)
      if lineEndIndex is -1
        lineEndIndex = Infinity

      # Grab the next line from the text buffer and split it into tokens.
      line = text.substring lineBeginIndex, lineEndIndex
      tokens = tokenizer.tokenize line
      console.log "check row", row, line

      # Loop through the tokens and process each one that looks like a word. We
      # build up a list of every word (token) and its position within the line.
      startIndex = 0
      words = []
      for token in tokens
        # If we don't have at least one character, skip it.
        if not /\w/.test(token)
          continue

        # Figure out where this token appears in the buffer. We have to do this
        # since we'll be skipping over whitespace and non-word tokens. Once we
        # have the components, add it to the list.
        tokenIndex = line.indexOf token, startSearch;
        startSearch = tokenIndex + token.length;
        words.push { word: token, start: tokenIndex, end: startSearch, t: line.substring(tokenIndex, startSearch) }

      console.log "words", words

      # Move to the next line
      lineBeginIndex = lineEndIndex + 1
      row++

    # Return the resulting misspellings.
    console.log "done", misspellings
    {id: args.id, misspellings: misspellings}

  suggest: (args, word) ->
    # Make sure our deferred initialization is done.
    @init()

    # Gather up a list of corrections and put them into a custom object that has
    # the priority of the plugin, the index in the results, and the word itself.
    # We use this to intersperse the results together to avoid having the
    # preferred answer for the second plugin below the least preferred of the
    # first.
    suggestions = []

    for checker in @checkers
      # We only care if this plugin contributes to checking to suggestions.
      if not checker.isEnabled() or not checker.providesSuggestions(args)
        continue

      # Get the suggestions for this word.
      index = 0
      priority = checker.getPriority()

      for suggestion in checker.suggest(args, word)
        suggestions.push {isSuggestion: true, priority: priority, index: index++, suggestion: suggestion, label: suggestion}

    # Once we have the suggestions, then sort them to intersperse the results.
    keys = Object.keys(suggestions).sort (key1, key2) ->
      value1 = suggestions[key1]
      value2 = suggestions[key2]
      weight1 = value1.priority + value1.index
      weight2 = value2.priority + value2.index

      if weight1 isnt weight2
        return weight1 - weight2

      return value1.suggestion.localeCompare(value2.suggestion)

    # Go through the keys and build the final list of suggestions. As we go
    # through, we also want to remove duplicates.
    results = []
    seen = []
    for key in keys
      s = suggestions[key]
      if seen.hasOwnProperty s.suggestion
        continue
      results.push s
      seen[s.suggestion] = 1

    # We also grab the "add to dictionary" listings.
    that = this
    keys = Object.keys(@checkers).sort (key1, key2) ->
      value1 = that.checkers[key1]
      value2 = that.checkers[key2]
      value1.getPriority() - value2.getPriority()

    for key in keys
      # We only care if this plugin contributes to checking to suggestions.
      checker = @checkers[key]
      if not checker.isEnabled() or not checker.providesAdding(args)
        continue

      # Add all the targets to the list.
      targets = checker.getAddingTargets args
      for target in targets
        target.plugin = checker
        target.word = word
        target.isSuggestion = false
        results.push target

    # Return the resulting list of options.
    results

  addMisspellings: (misspellings, row, range, lineBeginIndex, text) ->
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
          markBeginIndex = range[0] - lineBeginIndex + substringIndex
          markEndIndex = markBeginIndex + part.length
          misspellings.push([[row, markBeginIndex], [row, markEndIndex]])

        substringIndex += part.length

      return

    # There were no spaces, so just return the entire list.
    misspellings.push([
      [row, range[0] - lineBeginIndex],
      [row, range[1] - lineBeginIndex]
    ])

  init: ->
    # See if we need to initialize the system checkers.
    if @localeCheckers is null
      # Initialize the collection. If we aren't using any, then stop doing anything.
      console.log "spell-check-test: loading locales", @useLocales, @locales
      @localeCheckers = []

      if @useLocales
        # If we have a blank location, use the default based on the process. If
        # set, then it will be the best language.
        if not @locales.length
          defaultLocale = process.env.LANG
          if defaultLocale
            @locales = [defaultLocale.split('.')[0]]

        # If we can't figure out the language from the process, check the
        # browser. After testing this, we found that this does not reliably
        # produce a proper IEFT tag for languages; on OS X, it was providing
        # "English" which doesn't work with the locale selection. To avoid using
        # it, we use some tests to make sure it "looks like" an IEFT tag.
        if not @locales.length
          defaultLocale = navigator.language
          if defaultLocale and defaultLocale.length is 5
            separatorChar = defaultLocale.charAt(2)
            if separatorChar is '_' or separatorChar is '-'
              @locales = [defaultLocale]

        # If we still can't figure it out, use US English. It isn't a great
        # choice, but it is a reasonable default not to mention is can be used
        # with the fallback path of the `spellchecker` package.
        if not @locales.length
          @locales = ['en_US']

        # Go through the new list and create new locale checkers.
        SystemChecker = require "./system-checker"
        for locale in @locales
          checker = new SystemChecker locale, @localePaths
          @addSpellChecker checker
          @localeCheckers.push checker

    # See if we need to reload the known words.
    if @knownWordsChecker is null
      console.log "spell-check-test: loading known words", @knownWords
      KnownWordsChecker = require './known-words-checker.coffee'
      @knownWordsChecker = new KnownWordsChecker @knownWords
      @knownWordsChecker.enableAdd = @addKnownWords
      @addSpellChecker @knownWordsChecker

  deactivate: ->
    @checkers = []
    @locales = []
    @localePaths = []
    @useLocales=  false
    @localeCheckers = null
    @knownWords = []
    @addKnownWords = false
    @knownWordsChecker = null

  reloadLocales: ->
    if @localeCheckers
      console.log "spell-check-test: unloading locales"
      for localeChecker in @localeCheckers
        @removeSpellChecker localeChecker
      @localeCheckers = null

  reloadKnownWords: ->
    if @knownWordsChecker
      console.log "spell-check-test: unloading known words"
      @removeSpellChecker @knownWordsChecker
      @knownWordsChecker = null

manager = new SpellCheckerManager
module.exports = manager

#    KnownWordsChecker = require './known-words-checker.coffee'
#    knownWords = atom.config.get('spell-check-test.knownWords')
#    addKnownWords = atom.config.get('spell-check-test.addKnownWords')
