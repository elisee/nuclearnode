window.channel = {}
muteDisconnect = false

initApp -> channel.logic.init ->
  channel.socket = io.connect null, reconnect: false

  channel.socket.on 'connect', -> channel.socket.emit 'joinChannel', app.channel.service, app.channel.name
  channel.socket.on 'disconnect', onDisconnected
  channel.socket.on 'noGuestsAllowed', -> channel.appendToChat 'Info', i18n.t 'nuclearnode:chat.noGuestsAllowed'; muteDisconnect = true
  channel.socket.on 'banned', -> channel.appendToChat 'Info', i18n.t 'nuclearnode:chat.banned'; muteDisconnect = true

  channel.socket.on 'channelData', onChannelDataReceived

  channel.socket.on 'addUser', onUserAdded
  channel.socket.on 'removeUser', onUserRemoved
  channel.socket.on 'setUserRole', onUserRoleSet

  channel.socket.on 'addActor', onActorAdded
  channel.socket.on 'removeActor', onActorRemoved

  channel.socket.on 'chatMessage', onChatMessageReceived

  channel.socket.on 'settings:room.welcomeMessage', onWelcomeMessageUpdated
  channel.socket.on 'settings:room.guestAccess', onGuestAccessUpdated
  channel.socket.on 'banUser', onUserBanned
  channel.socket.on 'unbanUser', onUserUnbanned

  tabButtons = document.querySelectorAll('#SidebarTabButtons button')
  for tabButton in tabButtons
    tabButton.addEventListener 'click', onSidebarTabButtonClicked

  document.getElementById('ChatInputBox').addEventListener 'keydown', onSubmitChatMessage

  document.body.addEventListener 'click', (event) ->
    return if event.target.tagName != 'BUTTON'
    if event.target.className == 'BanUser'
      console.log event.target.dataset.displayName
      bannedUser = { authId: event.target.dataset.authId, displayName: event.target.dataset.displayName }
      channel.socket.emit 'banUser', bannedUser
    else if event.target.className == 'UnbanUser'
      channel.socket.emit 'unbanUser', event.target.dataset.authId
  return

# Channel & user presence
onDisconnected = ->
  channel.appendToChat 'Info', i18n.t 'nuclearnode:chat.disconnected' if ! muteDisconnect
  channel.logic.onDisconnected()

onChannelDataReceived = (data) ->
  channel.data = data

  if channel.data.welcomeMessage.length > 0
    channel.appendToChat 'Info', channel.data.welcomeMessage

  channel.data.usersByAuthId = {}
  channel.data.usersByAuthId[user.authId] = user for user in channel.data.users
  app.user.role = channel.data.usersByAuthId[app.user.authId].role

  updateChannelUsersCounter()

  channel.data.actorsByAuthId = {}
  channel.data.actorsByAuthId[actor.authId] = actor for actor in channel.data.actors

  renderSettings()

  channel.logic.onChannelDataReceived()
  return

onUserAdded = (user) ->
  channel.appendToChat 'Info', i18n.t 'nuclearnode:chat.userJoined', user: JST['nuclearnode/chatUser'] { user, i18n, app }
  channel.data.users.push user
  channel.data.usersByAuthId[user.authId] = user

  updateChannelUsersCounter()

  channel.logic.onUserAdded user
  return

onUserRemoved = (authId) ->
  user = channel.data.usersByAuthId[authId]
  channel.appendToChat 'Info', i18n.t 'nuclearnode:chat.userLeft', user: JST['nuclearnode/chatUser'] { user, i18n, app }
  delete channel.data.usersByAuthId[authId]
  channel.data.users.splice channel.data.users.indexOf(user), 1

  updateChannelUsersCounter()

  channel.logic.onUserRemoved user
  return

onUserRoleSet = (data) ->
  user = channel.data.usersByAuthId[data.userAuthId]
  user.role = data.role

  if data.userAuthId == app.user.authId
    app.user.role = data.role
    renderSettings()

  channel.appendToChat 'Info', i18n.t 'nuclearnode:chat.userRoleSet', user: JST['nuclearnode/chatUser']( { user, i18n, app } ), role: i18n.t('nuclearnode:userRoles.' + user.role)

onActorAdded = (actor) ->
  channel.data.actors.push actor
  channel.data.actorsByAuthId[actor.authId] = actor

  channel.logic.onActorAdded actor
  return

onActorRemoved = (authId) ->
  actor = channel.data.actorsByAuthId[authId]
  delete channel.data.actorsByAuthId[authId]
  channel.data.actors.splice channel.data.actors.indexOf(actor), 1

  channel.logic.onActorRemoved actor
  return

updateChannelUsersCounter = ->
  document.querySelector('#App header .ChannelUsers').textContent = if channel.data.users.length > 0 then channel.data.users.length else ''

# Sidebar
onSidebarTabButtonClicked = (event) ->
  oldActiveButton = document.querySelector('#SidebarTabButtons button.Active')
  oldActiveButton.classList.remove 'Active'
  event.target.classList.add 'Active'

  oldActiveTab = document.querySelector('#SidebarTabs > div.Active')
  oldActiveTab.classList.remove 'Active'
  document.getElementById(event.target.dataset.tab + 'Tab').classList.add 'Active'
  return

# Chat
onChatMessageReceived = (message) ->
  if message.userAuthId?
    channel.appendToChat 'Message',
      JST['nuclearnode/chatMessage']
        text: message.text
        author: JST['nuclearnode/chatUser']
          user: channel.data.usersByAuthId[message.userAuthId]
          i18n: i18n
          app: app
  else
    channel.appendToChat 'Info', i18n.t 'nuclearnode:chat.' + message.text

  return

onSubmitChatMessage = (event) ->
  return if event.keyCode != 13 or event.shiftKey
  event.preventDefault()
  channel.socket.emit 'chatMessage', this.value
  this.value = ''
  return

maxChatLogHistory = 100

channel.appendToChat = (type, content) ->
  chatLogElement = document.getElementById('ChatLog')

  date = new Date()
  hours = date.getHours()
  hours = (if hours < 10 then '0' else '') + hours
  minutes = date.getMinutes()
  minutes = (if minutes < 10 then '0' else '') + minutes
  time = "#{hours}:#{minutes}"

  isChatLogScrolledToBottom = chatLogElement.scrollTop >= chatLogElement.scrollHeight - chatLogElement.clientHeight
  chatLogElement.insertAdjacentHTML 'beforeend', JST['nuclearnode/chatLogItem']( type: type, content: content, time: time, i18n: i18n )
  chatLogElement.scrollTop = chatLogElement.scrollHeight if isChatLogScrolledToBottom

  if isChatLogScrolledToBottom and chatLogElement.querySelectorAll('li').length > maxChatLogHistory
    oldestLogEntry = chatLogElement.querySelector('li:first-of-type')
    oldestLogEntry.parentNode.removeChild(oldestLogEntry)
  return

# Settings
renderSettings = ->
  settingsTab = document.getElementById('SettingsTab')
  settingsTab.innerHTML = JST['settings']( app: app, channel: channel, i18n: i18n )

  if app.user.role in [ 'host', 'hubAdministrator' ]
    settingsTab.querySelector('input[name=welcomeMessage]').addEventListener 'change', (event) ->
      channel.socket.emit 'settings:room.welcomeMessage', event.target.value

    settingsTab.querySelector('select[name=guestAccess]').addEventListener 'change', (event) ->
      channel.socket.emit 'settings:room.guestAccess', event.target.value

  channel.logic.onSettingsSetup settingsTab

onWelcomeMessageUpdated = (welcomeMessage) ->
  channel.data.welcomeMessage = welcomeMessage

  channel.appendToChat 'Info', i18n.t 'nuclearnode:settingsUpdate.room.welcomeMessage', welcomeMessage: welcomeMessage
  if app.user.role not in [ 'host', 'hubAdministrator' ]
    document.querySelector('#SettingsTab .WelcomeMessage').textContent = welcomeMessage
  else
    document.querySelector('#SettingsTab input[name=welcomeMessage]').value = welcomeMessage

onGuestAccessUpdated = (guestAccess) ->
  channel.data.guestAccess = guestAccess

  channel.appendToChat 'Info', i18n.t 'nuclearnode:settingsUpdate.room.guestAccess', guestAccess: i18n.t "nuclearnode:settings.room.guestAccess.#{guestAccess}"
  if app.user.role not in [ 'host', 'hubAdministrator' ]
    document.querySelector('#SettingsTab .GuestAccess').textContent = i18n.t "nuclearnode:settings.room.guestAccess.#{guestAccess}"
  else
    document.querySelector('#SettingsTab select[name=guestAccess]').value = guestAccess

onUserBanned = (bannedUser) ->
  channel.appendToChat 'Info', i18n.t 'nuclearnode:chat.userBanned', { user: bannedUser.displayName }
  
  bannedUsersElement = document.querySelector('#SettingsTab .BannedUsers')

  if Object.keys(channel.data.bannedUsersByAuthId).length == 0
    bannedUsersElement.innerHTML = ''

  channel.data.bannedUsersByAuthId[bannedUser.authId] = bannedUser

  bannedUsersElement.insertAdjacentHTML 'beforeend', JST['nuclearnode/bannedUser'] { bannedUser, app, channel, i18n }
  return

onUserUnbanned = (bannedUser) ->
  channel.appendToChat 'Info', i18n.t 'nuclearnode:chat.userUnbanned', { user: bannedUser.displayName }

  delete channel.data.bannedUsersByAuthId[bannedUser.authId]
  liElement = document.querySelector("#SettingsTab .BannedUsers li[data-auth-id=\"#{bannedUser.authId}\"]")
  liElement.parentElement.removeChild liElement

  if Object.keys(channel.data.bannedUsersByAuthId).length == 0
    noneElement = document.createElement 'li'
    noneElement.textContent = i18n.t('nuclearnode:settings.room.bannedUsers.none')
    document.querySelector('#SettingsTab .BannedUsers').appendChild noneElement

  return