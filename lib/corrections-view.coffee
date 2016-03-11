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
        # Build up the arguments object for this buffer and text.
        projectPath = null
        relativePath = null
        if buffer?.file?.path
          [projectPath, relativePath] = atom.project.relativizePath(buffer.file.path)
        args = {
          id: @id,
          projectPath: projectPath,
          relativePath: relativePath
        }

        # Send the "add" request to the plugin.
        item.plugin.add args, item

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
