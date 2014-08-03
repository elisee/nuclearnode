window.AudioContext = window.AudioContext or window.webkitAudioContext
if window.AudioContext?
  audioCtx = new AudioContext()
  masterGain = audioCtx.createGain()
  masterGain.gain.value = 0.5
  masterGain.connect audioCtx.destination

window.audio =
  sounds: {}
  masterGain: masterGain

  loadSound: (url, callback) ->
    snd = buffer: null
    audio.sounds[url] = snd

    return setTimeout ( -> callback null, snd ), 0 unless audioCtx?

    xhr = new XMLHttpRequest()
    xhr.open 'GET', url, true
    xhr.responseType = 'arraybuffer'

    xhr.onload = (e) ->
      # Local file access returns status code 0
      return unless @status in [ 200, 0 ]

      audioCtx.decodeAudioData @response, (buffer) =>
        snd.buffer = buffer
        callback null, snd if callback?

    xhr.send()
      
    return

  playSound: (snd, options) ->
    return unless audioCtx?
    options or= {}

    gainNode = audioCtx.createGain()
    gainNode.gain.value = options.volume or 1
    gainNode.connect masterGain

    source = audioCtx.createBufferSource()
    source.buffer = snd.buffer
    source.loop = options.loop == true
    source.connect gainNode

    source.start 0
    source

  stopSource: (source) ->
    return unless audioCtx?
    source.stop 0
