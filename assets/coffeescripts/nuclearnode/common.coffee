overlay = null

window.initApp = ->
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

  # Overlay / Log in
  overlay = document.getElementById('Overlay')
  overlay.addEventListener 'click', onOverlayClicked
  if app.user.isGuest
    document.getElementById('LogInButton').addEventListener 'click', onLogInButtonClicked

suppressBackspace = (event) ->
  if event.keyCode == 8 and not /input|textarea/i.test(event.target.nodeName)
    event.preventDefault()
    return false
  return true

onToggleMenuButtonClicked = (event) ->
  document.getElementById('AppsBar').classList.toggle 'Hidden'

# Log in
onLogInButtonClicked = ->
  overlay.classList.add 'Enabled'
  document.getElementById('LogInDialog').classList.add 'Active'

onOverlayClicked = (event) ->
  return if overlay != event.target

  document.querySelector('#Overlay > div.Active').classList.remove 'Active'
  document.getElementById('Overlay').classList.remove 'Enabled'