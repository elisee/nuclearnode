window.channel = {}

i18n.init app.i18nOptions, ->
  initApp()

  channel.socket = io.connect null, reconnect: false

  channel.socket.on 'connect', -> channel.socket.emit 'joinChannel', app.channel.name
  channel.socket.on 'disconnect', -> channel.logic.onDisconnected()
  channel.socket.on 'channelData', onChannelDataReceived
  channel.socket.on 'addUser', onUserAdded
  channel.socket.on 'removeUser', onUserRemoved
  channel.socket.on 'addActor', onActorAdded
  channel.socket.on 'removeActor', onActorRemoved
  channel.socket.on 'chatMessage', onChatMessageReceived

  tabButtons = document.querySelectorAll('#SidebarTabButtons button')
  for tabButton in tabButtons
    tabButton.addEventListener 'click', onSidebarTabButtonClicked

  document.getElementById('ChatInputBox').addEventListener 'keydown', onSubmitChatMessage

  channel.logic.init()
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
  appendToChat i18n.t 'nuclearnode:chat.userJoined', user: user.displayName
  channel.data.users.push user
  channel.data.usersByAuthId[user.authId] = user

  updateChannelUsersCounter()

  channel.logic.onUserAdded user
  return

onUserRemoved = (authId) ->
  user = channel.data.usersByAuthId[authId]
  appendToChat i18n.t 'nuclearnode:chat.userLeft', user: user.displayName
  delete channel.data.usersByAuthId[authId]
  channel.data.users.splice channel.data.users.indexOf(user), 1

  updateChannelUsersCounter()

  channel.logic.onUserRemoved user
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
onChatMessageReceived = (message) -> appendToChat message.text, channel.data.usersByAuthId[message.userAuthId]  

onSubmitChatMessage = (event) ->
  return if event.keyCode != 13 or event.shiftKey
  event.preventDefault()
  channel.socket.emit 'chatMessage', this.value
  this.value = ''
  return

appendToChat = (text, author) ->
  ChatLog = document.getElementById('ChatLog')

  date = new Date()
  hours = date.getHours()
  hours = (if hours < 10 then '0' else '') + hours
  minutes = date.getMinutes()
  minutes = (if minutes < 10 then '0' else '') + minutes
  time = "#{hours}:#{minutes}"

  isChatLogScrolledToBottom = ChatLog.scrollTop >= ChatLog.scrollHeight - ChatLog.clientHeight
  ChatLog.insertAdjacentHTML 'beforeend', JST['nuclearnode/chatLogItem']( text: text, author: author, time: time )
  ChatLog.scrollTop = ChatLog.scrollHeight if isChatLogScrolledToBottom
  return
