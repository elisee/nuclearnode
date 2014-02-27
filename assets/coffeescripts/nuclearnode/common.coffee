overlay = null

window.initApp = ->
  overlay = document.getElementById('Overlay')

  document.getElementById('App').classList.remove 'Fade'
  
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
  overlay.addEventListener 'click', onOverlayClicked
  if app.user.isGuest
    document.getElementById('LogInButton').addEventListener 'click', onLogInButtonClicked

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

