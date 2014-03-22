window.channel = {}

initApp -> channel.logic.init ->
  channel.socket = io.connect null, reconnect: false

  channel.socket.on 'connect', -> channel.socket.emit 'joinChannel', app.channel.service, app.channel.name
  channel.socket.on 'disconnect', ->
    appendToChat 'Info', i18n.t 'nuclearnode:chat.disconnected'
    channel.logic.onDisconnected()
  channel.socket.on 'channelData', onChannelDataReceived

  channel.socket.on 'addUser', onUserAdded
  channel.socket.on 'removeUser', onUserRemoved
  channel.socket.on 'setUserRole', onUserRoleSet

  channel.socket.on 'addActor', onActorAdded
  channel.socket.on 'removeActor', onActorRemoved

  channel.socket.on 'chatMessage', onChatMessageReceived

  tabButtons = document.querySelectorAll('#SidebarTabButtons button')
  for tabButton in tabButtons
    tabButton.addEventListener 'click', onSidebarTabButtonClicked

  document.getElementById('ChatInputBox').addEventListener 'keydown', onSubmitChatMessage
  return

# Channel & user presence
onChannelDataReceived = (data) ->
  channel.data = data

  channel.data.usersByAuthId = {}
  channel.data.usersByAuthId[user.authId] = user for user in channel.data.users

  updateChannelUsersCounter()

  channel.data.actorsByAuthId = {}
  channel.data.actorsByAuthId[actor.authId] = actor for actor in channel.data.actors

  channel.logic.onChannelDataReceived()
  return

onUserAdded = (user) ->
  appendToChat 'Info', i18n.t 'nuclearnode:chat.userJoined', user: JST['nuclearnode/chatUser']( user: user, i18n: i18n )
  channel.data.users.push user
  channel.data.usersByAuthId[user.authId] = user

  updateChannelUsersCounter()

  channel.logic.onUserAdded user
  return

onUserRemoved = (authId) ->
  user = channel.data.usersByAuthId[authId]
  appendToChat 'Info', i18n.t 'nuclearnode:chat.userLeft', user: JST['nuclearnode/chatUser']( user: user, i18n: i18n )
  delete channel.data.usersByAuthId[authId]
  channel.data.users.splice channel.data.users.indexOf(user), 1

  updateChannelUsersCounter()

  channel.logic.onUserRemoved user
  return

onUserRoleSet = (data) ->
  user = channel.data.usersByAuthId[data.userAuthId]
  user.role = data.role

  appendToChat 'Info', i18n.t 'nuclearnode:chat.userRoleSet', user: JST['nuclearnode/chatUser']( user: user, i18n: i18n ), role: i18n.t('nuclearnode:userRoles.' + user.role)

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
    appendToChat 'Message',
      JST['nuclearnode/chatMessage']
        text: message.text
        author: JST['nuclearnode/chatUser']
          user: channel.data.usersByAuthId[message.userAuthId]
          i18n: i18n
  else
    appendToChat 'Info', i18n.t 'nuclearnode:chat.' + message.text

  return

onSubmitChatMessage = (event) ->
  return if event.keyCode != 13 or event.shiftKey
  event.preventDefault()
  channel.socket.emit 'chatMessage', this.value
  this.value = ''
  return

maxChatLogHistory = 100

appendToChat = (type, content) ->
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
