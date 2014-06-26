overlay = null

window.initApp = (callback) -> i18n.init window.app.i18nOptions, ->
  # Fade in
  document.getElementById('App').classList.remove 'Fade'

  # Prevent navigating to another page accidentally while trying to erase text
  # Based on http://stackoverflow.com/questions/3850442/how-to-prevent-browsers-default-history-back-action-for-backspace-button-with-j
  document.addEventListener 'keydown', suppressBackspace
  document.addEventListener 'keypress', suppressBackspace

  # Apps bar
  hubSocket = io.connect app.hubBaseURL, reconnect: true

  hubSocket.on 'connect', ->
    for appUsersElement in document.querySelectorAll("#AppsBar .AppUsers")
      appUsersElement.textContent = ''

    hubSocket.emit 'app', app.appId

  hubSocket.on 'appUsers', (usersByAppId) ->
    for appId, users of usersByAppId
      document.querySelector("##{appId}AppLink .AppUsers").textContent = if users > 0 then users else ''

  document.getElementById('ToggleMenuButton').addEventListener 'click', onToggleMenuButtonClicked

  # Audio volume
  audioVolumeSlider = document.querySelector('#App > header .AudioVolume input[type=range]')

  audioVolumeSlider.addEventListener 'change', (event) ->
    audio.masterGain.gain.value = audioVolumeSlider.value / 100
    if audio.savedVolume?
      audio.savedVolume = null
      toggleAudioIcon.src = '/images/nuclearnode/AudioVolume.png'
    return

  toggleAudioButton = document.querySelector('#App > header button.ToggleAudio')
  toggleAudioIcon = toggleAudioButton.querySelector('img')
  toggleAudioButton.addEventListener 'click', (event) ->
    return if ! window.audio?

    if audio.savedVolume?
      audio.masterGain.gain.value = audio.savedVolume
      audioVolumeSlider.value = Math.round(audio.savedVolume * 100)
      audio.savedVolume = null
      toggleAudioIcon.src = '/images/nuclearnode/AudioVolume.png'
    else
      audio.savedVolume = audio.masterGain.gain.value
      audio.masterGain.gain.value = 0
      audioVolumeSlider.value = 0
      toggleAudioIcon.src = '/images/nuclearnode/AudioMuted.png'

    return

  if ! window.audio?
    toggleAudioIcon.src = '/images/nuclearnode/AudioMuted.png'
    audioVolumeSlider.style.display = 'none'

  # Close ads
  for adCloseButton in document.querySelectorAll(".AdClose button")
    adCloseButton.addEventListener 'click', (event) ->
      event.currentTarget.parentElement.parentElement.classList.remove 'Show'

  # Overlay / Log in
  overlay = document.getElementById('Overlay')
  overlay.addEventListener 'click', onOverlayClicked
  if app.user.isGuest
    document.getElementById('LogInButton').addEventListener 'click', onLogInButtonClicked

  callback()

suppressBackspace = (event) ->
  if event.keyCode == 8 and not /input|textarea/i.test(event.target.nodeName)
    event.preventDefault()
    return false
  return true

onToggleMenuButtonClicked = (event) ->
  document.body.classList.toggle 'AppsBarHidden'

# Log in
onLogInButtonClicked = ->
  overlay.classList.add 'Enabled'
  document.getElementById('LogInDialog').classList.add 'Active'

onOverlayClicked = (event) ->
  return if overlay != event.target

  document.querySelector('#Overlay > div.Active').classList.remove 'Active'
  document.getElementById('Overlay').classList.remove 'Enabled'
