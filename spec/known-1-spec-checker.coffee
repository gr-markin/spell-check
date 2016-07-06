SpecChecker = require './spec-checker'

class Known1SpecChecker extends SpecChecker
    constructor: () ->
      super("known-1", false, ["k1a", "ka"])

checker = new Known1SpecChecker
module.exports = checker
