{Range} = require 'atom'
{SelectListView} = require 'atom-space-pen-views'

module.exports =
class CorrectionsView extends SelectListView
  initialize: (@editor, @corrections, @marker) ->
    super
    @addClass('spell-check-test-corrections corrections popover-list')
    @attach()

  attach: ->
    @setItems(@corrections)
    @overlayDecoration = @editor.decorateMarker(@marker, type: 'overlay', item: this)

  attached: ->
    @storeFocusedElement()
    @focusFilterEditor()

  destroy: ->
    @cancel()
    @remove()

  confirmed: (item) ->
    @cancel()
    return unless item
    @editor.transact =>
      if item.isSuggestion
        # Update the buffer with the correction.
        @editor.setSelectedBufferRange(@marker.getRange())
        @editor.insertText(item.suggestion)
      else
        # Send the "add" request to the plugin.
        item.plugin.add @editor.buffer, item

  cancelled: ->
    @overlayDecoration.destroy()
    @restoreFocus()

  viewForItem: (item) ->
    element = document.createElement "li"
    if item.isSuggestion
      # This is a word replacement suggestion.
      element.textContent = item.label
    else
      # This is an operation such as add word.
      em = document.createElement "em"
      em.textContent = item.label
      element.appendChild em
    element

  getFilterKey: ->
    "label"

  selectNextItemView: ->
    super
    false

  selectPreviousItemView: ->
    super
    false

  getEmptyMessage: (itemCount) ->
    if itemCount is 0
      'No corrections'
    else
      super
