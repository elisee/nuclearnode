window.channel = {}
muteDisconnect = false
joinPartEnabled = true

chatLogElement = document.getElementById('ChatLog')

channel.start = -> initApp -> channel.logic.init ->
  channel.socket = io.connect reconnection: false, transports: [ 'websocket' ]

  embeddedChatTemplate = JST["nuclearnode/chats/#{app.channel.service}"]
  if embeddedChatTemplate?
    document.getElementById('EmbeddedChat').innerHTML = embeddedChatTemplate( channel : app.channel.name )
    document.getElementById('ChatTab').classList.add 'Embedded'

  channel.socket.on 'connect', -> channel.socket.emit 'joinChannel', app.channel.service, app.channel.name
  channel.socket.on 'disconnect', onDisconnected
  channel.socket.on 'noGuestsAllowed', -> channel.appendToChat 'Info', i18n.t 'nuclearnode:chat.noGuestsAllowed'; muteDisconnect = true
  channel.socket.on 'banned', -> channel.appendToChat 'Info', i18n.t 'nuclearnode:chat.banned'; muteDisconnect = true

  channel.socket.on 'channelData', onChannelDataReceived

  channel.socket.on 'addUser', onUserAdded
  channel.socket.on 'removeUser', onUserRemoved
  channel.socket.on 'setUserRole', onUserRoleSet
  channel.socket.on 'banUser', onUserBanned
  channel.socket.on 'unbanUser', onUserUnbanned

  channel.socket.on 'addActor', onActorAdded
  channel.socket.on 'removeActor', onActorRemoved

  channel.socket.on 'chatMessage', onChatMessageReceived

  channel.socket.on 'settings:room.welcomeMessage', onWelcomeMessageUpdated
  channel.socket.on 'settings:room.guestAccess', onGuestAccessUpdated
  channel.socket.on 'settings:livestream', onLivestreamUpdated

  tabButtons = document.querySelectorAll('#SidebarTabButtons button')
  for tabButton in tabButtons
    tabButton.addEventListener 'click', onSidebarTabButtonClicked

  document.getElementById('ChatInputBox').addEventListener 'keydown', onSubmitChatMessage

  document.body.addEventListener 'click', (event) ->
    return if event.target.tagName != 'BUTTON'
    switch event.target.className
      when 'BanUser'
        bannedUser = { authId: event.target.dataset.authId, displayName: event.target.dataset.displayName }
        channel.socket.emit 'banUser', bannedUser
      when 'UnbanUser'
        channel.socket.emit 'unbanUser', event.target.dataset.authId
      when 'ModUser'
        moddedUser = { authId: event.target.dataset.authId, displayName: event.target.dataset.displayName }
        channel.socket.emit 'modUser', moddedUser
      when 'UnmodUser'
        channel.socket.emit 'unmodUser', event.target.dataset.authId
  return


# Channel & user presence
onDisconnected = ->
  channel.appendToChat 'Info', i18n.t 'nuclearnode:chat.disconnected' if ! muteDisconnect
  channel.logic.onDisconnected()

onChannelDataReceived = (data) ->
  channel.data = data

  if channel.data.welcomeMessage.length > 0
    channel.appendToChat 'Info', escapeHTML(channel.data.welcomeMessage)

  channel.data.usersByAuthId = {}
  channel.data.usersByAuthId[user.authId] = user for user in channel.data.users
  app.user.role = channel.data.usersByAuthId[app.user.authId].role

  updateChannelUsersCounter()
  updateGuestChat()

  channel.data.actorsByAuthId = {}
  channel.data.actorsByAuthId[actor.authId] = actor for actor in channel.data.actors

  setupLivestream()
  renderSettings()

  channel.logic.onChannelDataReceived()
  return

onUserAdded = (user) ->
  channel.data.users.push user
  channel.data.usersByAuthId[user.authId] = user
  updateChannelUsersCounter()

  if joinPartEnabled
    if channel.data.users.length > app.public.joinPartMaxUsers
      joinPartEnabled = false
      channel.appendToChat 'Info', i18n.t 'nuclearnode:chat.joinPartDisabled'
    else
      channel.appendToChat 'Info', i18n.t 'nuclearnode:chat.userJoined', user: JST['nuclearnode/chatUser'] { user, i18n, app }

  channel.logic.onUserAdded user
  return

onUserRemoved = (authId) ->
  user = channel.data.usersByAuthId[authId]
  delete channel.data.usersByAuthId[authId]
  channel.data.users.splice channel.data.users.indexOf(user), 1
  updateChannelUsersCounter()

  if ! joinPartEnabled and channel.data.users.length <= app.public.joinPartMaxUsers
    joinPartEnabled = true

  if joinPartEnabled
    channel.appendToChat 'Info', i18n.t 'nuclearnode:chat.userLeft', user: JST['nuclearnode/chatUser'] { user, i18n, app }


  channel.logic.onUserRemoved user
  return

onUserRoleSet = (data) ->
  user = channel.data.usersByAuthId[data.userAuthId]
  user.role = data.role

  if data.userAuthId == app.user.authId
    app.user.role = data.role
    renderSettings()

  channel.appendToChat 'Info', i18n.t 'nuclearnode:chat.userRoleSet', user: JST['nuclearnode/chatUser']( { user, i18n, app } ), role: i18n.t('nuclearnode:userRoles.' + user.role)

onUserBanned = (bannedUser) ->
  channel.appendToChat 'Info', i18n.t 'nuclearnode:chat.userBanned', { user: bannedUser.displayName }

  bannedUsersElement = document.querySelector('#SettingsTab .BannedUsers')

  if Object.keys(channel.data.bannedUsersByAuthId).length == 0
    bannedUsersElement.innerHTML = ''

  channel.data.bannedUsersByAuthId[bannedUser.authId] = bannedUser

  bannedUsersElement.insertAdjacentHTML 'beforeend', JST['nuclearnode/bannedUser'] { bannedUser, app, channel, i18n }

  # remove all messages
  removed = i18n.t('nuclearnode:chat.removed')
  for elt in chatLogElement.querySelectorAll(".Author-#{bannedUser.authId.replace(/:/g,'_')}")
    elt.style.opacity = 0.4
    contentElt = elt.querySelector('.Content')
    contentElt.dataset.text = contentElt.textContent
    contentElt.textContent = removed
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
    channel.appendToChat "Message Author-#{message.userAuthId.replace(/:/g,'_')}",
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

isChatLogScrolledToBottom = -> chatLogElement.scrollTop >= chatLogElement.scrollHeight - chatLogElement.clientHeight - 15

channel.appendToChat = (type, content) ->
  date = new Date()
  hours = date.getHours()
  hours = (if hours < 10 then '0' else '') + hours
  minutes = date.getMinutes()
  minutes = (if minutes < 10 then '0' else '') + minutes
  time = "#{hours}:#{minutes}"

  wasChatLogScrolledToBottom = isChatLogScrolledToBottom()
  chatLogElement.insertAdjacentHTML 'beforeend', JST['nuclearnode/chatLogItem']( type: type, content: content, time: time, i18n: i18n )
  chatLogElement.scrollTop = chatLogElement.scrollHeight if wasChatLogScrolledToBottom

  if wasChatLogScrolledToBottom and chatLogElement.querySelectorAll('li').length > maxChatLogHistory
    oldestLogEntry = chatLogElement.querySelector('li:first-of-type')
    oldestLogEntry.parentNode.removeChild(oldestLogEntry)
  return


# Livestream
setupLivestream = ->
  streamBoxElement = document.querySelector('.StreamBox')

  livestreamCount = 0

  for livestream, childIndex in channel.data.livestreams
    livestreamName = "#{livestream.service}/#{livestream.channel}"
    livestreamHTML = JST["nuclearnode/livestreams/#{livestream.service}"] { channel: livestream.channel, app: app }

    livestreamCount++ if livestream.service != 'none'

    oldStreamElement = streamBoxElement.children[childIndex]
    if ! oldStreamElement?
      streamBoxElement.insertAdjacentHTML 'beforeend', livestreamHTML
    else if oldStreamElement.dataset.livestream != livestreamName
      insertPoint = oldStreamElement.nextSibling
      oldStreamElement.parentElement.removeChild oldStreamElement

      if insertPoint?
        insertPoint.insertAdjacentHTML 'beforebegin', livestreamHTML
      else
        streamBoxElement.insertAdjacentHTML 'beforeend', livestreamHTML

  streamBoxElement.dataset.count = livestreamCount
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

    for i in [0...channel.data.livestreams.length]
      do ->
        livestreamIndex = i
        livestreamServiceSelect = settingsTab.querySelector("table[data-livestream-index='#{i}'] select[name=livestreamService]")
        livestreamChannelInput  = settingsTab.querySelector("table[data-livestream-index='#{i}'] input[name=livestreamChannel]")

        livestreamServiceSelect.addEventListener 'change', (event) ->
          livestreamChannelInput.parentElement.parentElement.style.display = if event.target.value in [ 'none', 'talkgg' ] then 'none' else ''
          channel.socket.emit 'settings:livestream', livestreamIndex, event.target.value, livestreamChannelInput.value

        livestreamChannelInput.addEventListener 'change', (event) ->
          channel.socket.emit 'settings:livestream', livestreamIndex, livestreamServiceSelect.value, event.target.value

  channel.logic.onSettingsSetup settingsTab

escapeHTML = (x) -> x.replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;')

onWelcomeMessageUpdated = (welcomeMessage) ->
  channel.data.welcomeMessage = welcomeMessage

  channel.appendToChat 'Info', i18n.t 'nuclearnode:settingsUpdate.room.welcomeMessage', welcomeMessage: escapeHTML(welcomeMessage)
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

  updateGuestChat()

updateGuestChat = ->
  return if ! app.user.isGuest

  chatInputBoxElement = document.getElementById('ChatInputBox')
  if channel.data.guestAccess == 'noChat'
    chatInputBoxElement.placeholder = i18n.t('nuclearnode:chat.logInToChat')
    chatInputBoxElement.value = ''
    chatInputBoxElement.disabled = true
  else
    chatInputBoxElement.placeholder = i18n.t('nuclearnode:chat.typeHereToChat')
    chatInputBoxElement.disabled = false

onLivestreamUpdated = (data) ->
  channel.data.livestreams[data.index] = { service: data.service, channel: data.channel }

  if app.user.role in [ 'host', 'hubAdministrator' ]
    document.querySelector("#SettingsTab table[data-livestream-index='#{data.index}'] select[name=livestreamService]").value = data.service
    document.querySelector("#SettingsTab table[data-livestream-index='#{data.index}'] input[name=livestreamChannel]").value = data.channel

  setupLivestream()
  return

# Ads
lastAdRefreshTime = 0
channel.refreshAds = ->
  elapsedTime = Date.now() - lastAdRefreshTime
  return if elapsedTime < 30 * 1000
  lastAdRefreshTime = Date.now()

  wasChatLogScrolledToBottom = isChatLogScrolledToBottom()

  adsHTML =
    """
    <ins class='adsbygoogle'
       style='display:inline-block;width:300px;height:250px'
       data-ad-client='#{window.app.public.adwords.client}'
       data-ad-slot='#{window.app.public.adwords.slot300x250}'></ins>
    """
  for adBox in document.querySelectorAll(".NuclearSupportBox")
    adBox.classList.add 'Show'
    adBox.querySelector('.BoxContent').innerHTML = adsHTML
  (adsbygoogle = window.adsbygoogle || []).push({})

  chatLogElement.scrollTop = chatLogElement.scrollHeight if wasChatLogScrolledToBottom
