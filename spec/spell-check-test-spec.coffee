describe "Spell check", ->
  [workspaceElement, editor, editorElement, spellCheckModule] = []

  textForMarker = (marker) ->
    editor.getTextInBufferRange(marker.getBufferRange())

  getMisspellingMarkers = ->
    spellCheckModule.misspellingMarkersForEditor(editor)

  beforeEach ->
    workspaceElement = atom.views.getView(atom.workspace)

    waitsForPromise ->
      atom.packages.activatePackage('language-text')

    waitsForPromise ->
      atom.packages.activatePackage('language-javascript')

    waitsForPromise ->
      atom.workspace.open('sample.js')

    waitsForPromise ->
      atom.packages.activatePackage('spell-check-test').then ({mainModule}) ->
        spellCheckModule = mainModule

    runs ->
      atom.config.set('spell-check.grammars', [])

    runs ->
      jasmine.attachToDOM(workspaceElement)
      editor = atom.workspace.getActiveTextEditor()
      editorElement = atom.views.getView(editor)

  xit "decorates all misspelled words", ->
    atom.config.set('spell-check-test.locales', ['en-US'])
    editor.setText("This middle of thiss\nsentencts\n\nhas issues and the \"edn\" 'dsoe' too")
    atom.config.set('spell-check-test.grammars', ['source.js'])

    misspellingMarkers = null
    waitsFor ->
      misspellingMarkers = getMisspellingMarkers()
      misspellingMarkers.length > 0

    runs ->
      expect(misspellingMarkers.length).toBe 4
      expect(textForMarker(misspellingMarkers[0])).toEqual "thiss"
      expect(textForMarker(misspellingMarkers[1])).toEqual "sentencts"
      expect(textForMarker(misspellingMarkers[2])).toEqual "edn"
      expect(textForMarker(misspellingMarkers[3])).toEqual "dsoe"

  xit "decorates misspelled words with a leading space", ->
    atom.config.set('spell-check-test.locales', ['en-US'])
    editor.setText("\nchok bok")
    atom.config.set('spell-check-test.grammars', ['source.js'])

    misspellingMarkers = null
    waitsFor ->
      misspellingMarkers = getMisspellingMarkers()
      misspellingMarkers.length > 0

    runs ->
      expect(misspellingMarkers.length).toBe 2
      expect(textForMarker(misspellingMarkers[0])).toEqual "chok"
      expect(textForMarker(misspellingMarkers[1])).toEqual "bok"

  xit "allow entering of known words", ->
    atom.config.set('spell-check-test.knownWords', ['GitHub', '!github', 'codez'])
    atom.config.set('spell-check-test.locales', ['en-US'])
    editor.setText("GitHub (aka github): Where codez are builz.")
    atom.config.set('spell-check-test.grammars', ['source.js'])

    misspellingMarkers = null
    waitsFor ->
      misspellingMarkers = getMisspellingMarkers()
      misspellingMarkers.length > 0

    runs ->
      expect(misspellingMarkers.length).toBe 1
      expect(textForMarker(misspellingMarkers[0])).toBe "builz"

  xit "hides decorations when a misspelled word is edited", ->
    editor.setText('notaword')
    advanceClock(editor.getBuffer().getStoppedChangingDelay())
    atom.config.set('spell-check-test.grammars', ['source.js'])

    misspellingMarkers = null
    waitsFor ->
      misspellingMarkers = getMisspellingMarkers()
      misspellingMarkers.length > 0

    runs ->
      expect(misspellingMarkers.length).toBe 1
      editor.moveToEndOfLine()
      editor.insertText('a')
      advanceClock(editor.getBuffer().getStoppedChangingDelay())

      misspellingMarkers = getMisspellingMarkers()

      expect(misspellingMarkers.length).toBe 1
      expect(misspellingMarkers[0].isValid()).toBe false

  xdescribe "when spell checking for a grammar is removed", ->
    xit "removes all the misspellings", ->
      atom.config.set('spell-check-test.locales', ['en-US'])
      editor.setText('notaword')
      advanceClock(editor.getBuffer().getStoppedChangingDelay())
      atom.config.set('spell-check-test.grammars', ['source.js'])

      waitsFor ->
        getMisspellingMarkers().length > 0

      runs ->
        expect(getMisspellingMarkers().length).toBe 1
        atom.config.set('spell-check-test.grammars', [])
        expect(getMisspellingMarkers().length).toBe 0

  xdescribe "when spell checking for a grammar is toggled off", ->
    xit "removes all the misspellings", ->
      atom.config.set('spell-check-test.locales', ['en-US'])
      editor.setText('notaword')
      advanceClock(editor.getBuffer().getStoppedChangingDelay())
      atom.config.set('spell-check-test.grammars', ['source.js'])

      waitsFor ->
        getMisspellingMarkers().length > 0

      runs ->
        expect(getMisspellingMarkers().length).toBe 1
        atom.commands.dispatch(workspaceElement, 'spell-check-test:toggle')
        expect(getMisspellingMarkers().length).toBe 0

  xdescribe "when the editor's grammar changes to one that does not have spell check enabled", ->
    xit "removes all the misspellings", ->
      atom.config.set('spell-check-test.locales', ['en-US'])
      editor.setText('notaword')
      advanceClock(editor.getBuffer().getStoppedChangingDelay())
      atom.config.set('spell-check-test.grammars', ['source.js'])

      waitsFor ->
        getMisspellingMarkers().length > 0

      runs ->
        expect(getMisspellingMarkers().length).toBe 1
        editor.setGrammar(atom.grammars.selectGrammar('.txt'))
        expect(getMisspellingMarkers().length).toBe 0

  xdescribe "when 'spell-check-test:correct-misspelling' is triggered on the editor", ->
    xdescribe "when the cursor touches a misspelling that has corrections", ->
      xit "displays the corrections for the misspelling and replaces the misspelling when a correction is selected", ->
        atom.config.set('spell-check-test.locales', ['en-US'])
        editor.setText('tofether')
        advanceClock(editor.getBuffer().getStoppedChangingDelay())
        atom.config.set('spell-check-test.grammars', ['source.js'])

        waitsFor ->
          getMisspellingMarkers().length is 1

        runs ->
          expect(getMisspellingMarkers()[0].isValid()).toBe true

          atom.commands.dispatch editorElement, 'spell-check-test:correct-misspelling'

          correctionsElement = editorElement.querySelector('.corrections')
          expect(correctionsElement).toBeDefined()
          expect(correctionsElement.querySelectorAll('li').length).toBeGreaterThan 0
          expect(correctionsElement.querySelectorAll('li')[0].textContent).toBe "together"

          atom.commands.dispatch correctionsElement, 'core:confirm'

          expect(editor.getText()).toBe 'together'
          expect(editor.getCursorBufferPosition()).toEqual [0, 8]

          expect(getMisspellingMarkers()[0].isValid()).toBe false
          expect(editorElement.querySelector('.corrections')).toBeNull()

    xdescribe "when the cursor touches a misspelling that has no corrections", ->
      xit "displays a message saying no corrections found", ->
        atom.config.set('spell-check-test.locales', ['en-US'])
        editor.setText('zxcasdfysyadfyasdyfasdfyasdfyasdfyasydfasdf')
        advanceClock(editor.getBuffer().getStoppedChangingDelay())
        atom.config.set('spell-check-test.grammars', ['source.js'])

        waitsFor ->
          getMisspellingMarkers().length > 0

        runs ->
          atom.commands.dispatch editorElement, 'spell-check-test:correct-misspelling'
          expect(editorElement.querySelectorAll('.corrections').length).toBe 1
          expect(editorElement.querySelectorAll('.corrections li').length).toBe 0
          expect(editorElement.querySelector('.corrections').textContent).toBe "No corrections"

  xdescribe "when the editor is destroyed", ->
    xit "destroys all misspelling markers", ->
      atom.config.set('spell-check-test.locales', ['en-US'])
      editor.setText('mispelling')
      atom.config.set('spell-check-test.grammars', ['source.js'])

      waitsFor ->
        getMisspellingMarkers().length > 0

      runs ->
        editor.destroy()
        expect(getMisspellingMarkers().length).toBe 0

  describe "when using two plugins", ->
    it "no opinion on input means correctly spells", ->
      spellCheckModule.consumeSpellCheckers require.resolve('./known-1-spec-checker.coffee')
      spellCheckModule.consumeSpellCheckers require.resolve('./eot-spec-checker.coffee')
      atom.config.set('spell-check-test.locales', ['en-US'])
      atom.config.set('spell-check-test.useLocales', false)
      editor.setText('eot')
      atom.config.set('spell-check-test.grammars', ['source.js'])

      waitsFor ->
        getMisspellingMarkers().length > 0

      runs ->
        expect(getMisspellingMarkers().length).toBe 1
        editor.destroy()
        expect(getMisspellingMarkers().length).toBe 0

    it "correctly spelling k1a", ->
      spellCheckModule.consumeSpellCheckers require.resolve('./known-1-spec-checker.coffee')
      spellCheckModule.consumeSpellCheckers require.resolve('./eot-spec-checker.coffee')
      atom.config.set('spell-check-test.locales', ['en-US'])
      atom.config.set('spell-check-test.useLocales', false)
      editor.setText('k1a eot')
      atom.config.set('spell-check-test.grammars', ['source.js'])

      waitsFor ->
        getMisspellingMarkers().length > 0

      runs ->
        expect(getMisspellingMarkers().length).toBe 1
        editor.destroy()
        expect(getMisspellingMarkers().length).toBe 0
