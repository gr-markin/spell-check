# This is the task local handler for the manager so we can reuse the manager
# throughout the life of the task.
instance = undefined
tmpa = 1

reloadSettings = (data) ->
  if "locales" in data.args and instance.locales isnt data.args.locales
    instance.locales = data.args.locales

  instance.localePaths = data.args.localePaths
  instance.useLocales = data.args.useLocales
  instance.knownWords = data.args.knownWords
  instance.addKnownWords = data.args.addKnownWords

# Background task for checking the text of a buffer and returning the
# spelling. Since this can be an expensive operation, it is intended to be run
# in the background with the results returned asynchronously.
backgroundCheck = (data) ->
  # If `instance` isn't initialized, then we need to load the manager which can
  # load checkers which may be expensive.
  if not instance
    SpellCheckerManager = require './spell-check-manager.coffee'
    instance = SpellCheckerManager

  # We always update the settings, that way we pick up configuration from the
  # main process with every check. `reloadSettings` will intelligently handle
  # when we need to reload locales.
  reloadSettings data

  # Check the text and return the resulting spelling errors.
  misspellings = instance.check data.args, data.text
  {id: data.id, misspellings: misspellings.misspellings}

module.exports = backgroundCheck
