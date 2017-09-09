$ = undefined
App = undefined
_ = undefined
ace = undefined

bind = (fn, me) ->
  ->
    fn.apply me, arguments

require '../styles/index'
_ = require('underscore')
$ = require('jquery')
ace = require('brace')
require 'brace/mode/html'
require 'brace/mode/javascript'
require 'brace/mode/php'
require 'brace/mode/python'
require 'brace/mode/ruby'
require 'brace/mode/c_cpp'
require 'brace/mode/java'
require 'brace/mode/golang'
require 'brace/theme/vibrant_ink'
require 'brace/ext/searchbox'
App = do ->
  `var App`

  App = ->
    @onChange = bind(@onChange, this)
    @onClickFinish = bind(@onClickFinish, this)
    @onClickReference = bind(@onClickReference, this)
    @onClickInstructions = bind(@onClickInstructions, this)
    @onChangeLang = bind(@onChangeLang, this)
    @deactivatePowerMode = bind(@deactivatePowerMode, this)
    @activatePowerMode = bind(@activatePowerMode, this)
    @drawParticles = bind(@drawParticles, this)
    @onFrame = bind(@onFrame, this)
    @saveContent = bind(@saveContent, this)
    @$streakCounter = $('.streak-container .counter')
    @$streakBar = $('.streak-container .bar')
    @$exclamations = $('.streak-container .exclamations')
    @$reference = $('.reference-screenshot-container')
    @$nameTag = $('.name-tag')
    @$result = $('.result')
    @$editor = $('#editor')
    @canvas = @setupCanvas()
    @canvasContext = @canvas.getContext('2d')
    @$finish = $('.finish-button')
    @$body = $('body')
    @debouncedSaveContent = _.debounce(@saveContent, 300)
    @debouncedEndStreak = _.debounce(@endStreak, @STREAK_TIMEOUT)
    @throttledShake = _.throttle(@shake, 100, trailing: false)
    @throttledSpawnParticles = _.throttle(@spawnParticles, 25, trailing: false)
    @editor = @setupAce('ace/mode/javascript')
    @loadContent()
    @editor.focus()
    @editor.getSession().on 'change', @onChange
    $(window).on 'beforeunload', ->
      'Hold your horses!'
    $('.instructions-container, .instructions-button').on 'click', @onClickInstructions
    $('.language-selector').on 'change', @onChangeLang
    @$reference.on 'click', @onClickReference
    @$finish.on 'click', @onClickFinish
    @$nameTag.on 'click', ((_this) ->
      ->
        _this.getName true
    )(this)
    @getName()
    if typeof window.requestAnimationFrame == 'function'
      window.requestAnimationFrame @onFrame
    return

  App::POWER_MODE_ACTIVATION_THRESHOLD = 200
  App::STREAK_TIMEOUT = 10 * 1000
  App::MAX_PARTICLES = 500
  App::PARTICLE_NUM_RANGE = [
    5
    6
    7
    8
    9
    10
    11
    12
  ]
  App::PARTICLE_GRAVITY = 0.075
  App::PARTICLE_SIZE = 8
  App::PARTICLE_ALPHA_FADEOUT = 0.96
  App::PARTICLE_VELOCITY_RANGE =
    x: [
      -2.5
      2.5
    ]
    y: [
      -7
      -3.5
    ]
  App::PARTICLE_COLORS =
    'text': [
      255
      255
      255
    ]
    'text.xml': [
      255
      255
      255
    ]
    'keyword': [
      0
      221
      255
    ]
    'variable': [
      0
      221
      255
    ]
    'meta.tag.tag-name.xml': [
      0
      221
      255
    ]
    'keyword.operator.attribute-equals.xml': [
      0
      221
      255
    ]
    'constant': [
      249
      255
      0
    ]
    'constant.numeric': [
      249
      255
      0
    ]
    'support.constant': [
      249
      255
      0
    ]
    'string.attribute-value.xml': [
      249
      255
      0
    ]
    'string.unquoted.attribute-value.html': [
      249
      255
      0
    ]
    'entity.other.attribute-name.xml': [
      129
      148
      244
    ]
    'comment': [
      0
      255
      121
    ]
    'comment.xml': [
      0
      255
      121
    ]
  extension = 'js'
  App::EXCLAMATION_EVERY = 10
  App::EXCLAMATIONS = [
    'Super!'
    'Radical!'
    'Fantastic!'
    'Great!'
    'OMG'
    'Whoah!'
    ':O'
    'Nice!'
    'Splendid!'
    'Wild!'
    'Grand!'
    'Impressive!'
    'Stupendous!'
    'Extreme!'
    'Awesome!'
  ]
  App::currentStreak = 0
  App::powerMode = false
  App::particles = []
  App::particlePointer = 0
  App::lastDraw = 0

  App::setupAce = (languageMode) ->
    editor = undefined
    editor = ace.edit('editor')
    editor.setShowPrintMargin false
    editor.setHighlightActiveLine false
    editor.setFontSize 20
    editor.setTheme 'ace/theme/vibrant_ink'
    editor.getSession().setMode languageMode
    editor.session.setOption 'useWorker', false
    editor.session.setFoldStyle 'manual'
    editor.$blockScrolling = Infinity
    editor

  App::setupCanvas = ->
    canvas = undefined
    canvas = $('.canvas-overlay')[0]
    canvas.width = window.innerWidth
    canvas.height = window.innerHeight
    canvas

  App::getName = (forceUpdate) ->
    name = undefined
    name = !forceUpdate and localStorage['name'] or prompt('What\'s your name?')
    localStorage['name'] = name
    if name
      return @$nameTag.text(name)
    return

  App::loadContent = ->
    content = undefined
    if !(content = localStorage['content'])
      return
    @editor.setValue content, -1

  App::saveContent = ->
    localStorage['content'] = @editor.getValue()

  App::onFrame = (time) ->
    @drawParticles time - (@lastDraw)
    @lastDraw = time
    if typeof window.requestAnimationFrame == 'function' then window.requestAnimationFrame(@onFrame) else undefined

  App::increaseStreak = ->
    @currentStreak++
    if @currentStreak > 0 and @currentStreak % @EXCLAMATION_EVERY == 0
      @showExclamation()
    if @currentStreak >= @POWER_MODE_ACTIVATION_THRESHOLD and !@powerMode
      @activatePowerMode()
    @refreshStreakBar()
    @renderStreak()

  App::endStreak = ->
    @currentStreak = 0
    @renderStreak()
    @deactivatePowerMode()

  App::renderStreak = ->
    @$streakCounter.text(@currentStreak).removeClass 'bump'
    _.defer ((_this) ->
      ->
        _this.$streakCounter.addClass 'bump'
    )(this)

  App::refreshStreakBar = ->
    @$streakBar.css
      'webkit-transform': 'scaleX(1)'
      'transform': 'scaleX(1)'
      'transition': 'none'
    _.defer ((_this) ->
      ->
        _this.$streakBar.css
          'webkit-transform': ''
          'transform': ''
          'transition': 'all ' + _this.STREAK_TIMEOUT + 'ms linear'
    )(this)

  App::showExclamation = ->
    $exclamation = undefined
    $exclamation = $('<span>').addClass('exclamation').text(_.sample(@EXCLAMATIONS))
    @$exclamations.prepend $exclamation
    setTimeout (->
      $exclamation.remove()
    ), 3000

  App::getCursorPosition = ->
    left = undefined
    ref = undefined
    top = undefined
    ref = @editor.renderer.$cursorLayer.getPixelPosition()
    left = ref.left
    top = ref.top
    left += @editor.renderer.gutterWidth + 4
    top -= @editor.renderer.scrollTop
    {
      x: left
      y: top
    }

  App::spawnParticles = (type) ->
    color = undefined
    numParticles = undefined
    ref = undefined
    x = undefined
    y = undefined
    if !@powerMode
      return
    ref = @getCursorPosition()
    x = ref.x
    y = ref.y
    numParticles = _(@PARTICLE_NUM_RANGE).sample()
    color = @getParticleColor(type)
    _(numParticles).times ((_this) ->
      ->
        _this.particles[_this.particlePointer] = _this.createParticle(x, y, color)
        _this.particlePointer = (_this.particlePointer + 1) % _this.MAX_PARTICLES
    )(this)

  App::getParticleColor = (type) ->
    @PARTICLE_COLORS[type] or [
      255
      255
      255
    ]

  App::createParticle = (x, y, color) ->
    {
      x: x
      y: y + 10
      alpha: 1
      color: color
      velocity:
        x: @PARTICLE_VELOCITY_RANGE.x[0] + Math.random() * (@PARTICLE_VELOCITY_RANGE.x[1] - (@PARTICLE_VELOCITY_RANGE.x[0]))
        y: @PARTICLE_VELOCITY_RANGE.y[0] + Math.random() * (@PARTICLE_VELOCITY_RANGE.y[1] - (@PARTICLE_VELOCITY_RANGE.y[0]))
    }

  App::drawParticles = (timeDelta) ->
    i = undefined
    len = undefined
    particle = undefined
    ref = undefined
    results = undefined
    @canvasContext.clearRect 0, 0, @canvas.width, @canvas.height
    ref = @particles
    results = []
    i = 0
    len = ref.length
    while i < len
      particle = ref[i]
      if particle.alpha <= 0.1
        i++
        continue
      particle.velocity.y += @PARTICLE_GRAVITY
      particle.x += particle.velocity.x
      particle.y += particle.velocity.y
      particle.alpha *= @PARTICLE_ALPHA_FADEOUT
      @canvasContext.fillStyle = 'rgba(' + particle.color.join(', ') + ', ' + particle.alpha + ')'
      results.push @canvasContext.fillRect(Math.round(particle.x - (@PARTICLE_SIZE / 2)), Math.round(particle.y - (@PARTICLE_SIZE / 2)), @PARTICLE_SIZE, @PARTICLE_SIZE)
      i++
    results

  App::shake = ->
    intensity = undefined
    x = undefined
    y = undefined
    if !@powerMode
      return
    intensity = 1 + 2 * Math.random() * Math.floor((@currentStreak - (@POWER_MODE_ACTIVATION_THRESHOLD)) / 100)
    x = intensity * (if Math.random() > 0.5 then -1 else 1)
    y = intensity * (if Math.random() > 0.5 then -1 else 1)
    @$editor.css 'margin', y + 'px ' + x + 'px'
    setTimeout ((_this) ->
      ->
        _this.$editor.css 'margin', ''
    )(this), 75

  App::activatePowerMode = ->
    @powerMode = true
    @$body.addClass 'power-mode'

  App::deactivatePowerMode = ->
    @powerMode = false
    @$body.removeClass 'power-mode'

  App::onClickInstructions = ->
    $('body').toggleClass 'show-instructions'
    if !$('body').hasClass('show-instructions')
      return @editor.focus()
    return

  App::onChangeLang = ->
    value = $('#language').val()
    extension = $('#language').children(':selected').attr('data-ext')
    @editor = @setupAce(value)
    return

  App::onClickReference = ->
    @$reference.toggleClass 'active'
    if !@$reference.hasClass('active')
      return @editor.focus()
    return

  App::onClickFinish = ->
    confirm = undefined
    confirm = prompt('This will show the results of your code. Doing this before the round is over WILL DISQUALIFY YOU. Are you sure you want to proceed? Type "yes" to confirm.')
    if (if confirm != null then confirm.toLowerCase() else undefined) == 'yes'
      @$result[0].contentWindow.postMessage @editor.getValue(), '*'
      @onClickDownload()
    #return this.$result.show();
    return

  App::onChange = (e) ->
    insertTextAction = undefined
    pos = undefined
    range = undefined
    token = undefined
    @debouncedSaveContent()
    insertTextAction = e.data.action == 'insertText'
    if insertTextAction
      @increaseStreak()
      @debouncedEndStreak()
    @throttledShake()
    range = e.data.range
    pos = if insertTextAction then range.end else range.start
    token = @editor.session.getTokenAt(pos.row, pos.column)
    _.defer ((_this) ->
      ->
        if token
          return _this.throttledSpawnParticles(token.type)
        return
    )(this)

  App::onClickDownload = ->
    $a = undefined
    $a = $('<a>').attr(
      download: 'solution.' + extension
      href: window.URL.createObjectURL(new Blob([ @editor.getValue() ], type: 'text/txt'))).appendTo('body')
    $a[0].click()

  App
$ ->
  new App
# ---
# generated by coffee-script 1.9.2

# ---
# generated by js2coffee 2.2.0