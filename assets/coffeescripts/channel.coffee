window.channel = {}

i18n.init window.app.i18nOptions, ->
  document.getElementById('App').classList.remove 'Fade'
  
  channel.socket = io.connect null, reconnect: false

  channel.socket.on 'connect', -> channel.socket.emit 'joinChannel', app.channel.name
  channel.socket.on 'channelData', onChannelDataReceived
  channel.socket.on 'addPlayer', onPlayerAdded
  channel.socket.on 'removePlayer', onPlayerRemoved
  channel.socket.on 'chatMessage', onChatMessageReceived

  document.getElementById('ToggleMenuButton').addEventListener 'click', onToggleMenuButtonClicked

  tabButtons = document.querySelectorAll('#SidebarTabButtons button')
  for tabButton in tabButtons
    tabButton.addEventListener 'click', onSidebarTabButtonClicked

  document.getElementById('ChatInputBox').addEventListener 'keydown', onSubmitChatMessage

  if app.user.isGuest
    document.getElementById('LogInButton').addEventListener 'click', onLogInButtonClicked

  return

# Channel & player presence
onChannelDataReceived = (data) ->
  channel.data = data
  channel.data.playersByAuthId = {}
  for player in channel.data.players
    channel.data.playersByAuthId[player.authId] = player

  channel.logic.onChannelDataReceived()
  return

onPlayerAdded = (player) ->
  appendToChat i18n.t 'chat.playerJoined', player: player.displayName
  channel.data.players.push player
  channel.data.playersByAuthId[player.authId] = player

  channel.logic.onPlayerAdded player
  return

onPlayerRemoved = (authId) ->
  player = channel.data.playersByAuthId[authId]
  appendToChat i18n.t 'chat.playerLeft', player: player.displayName
  delete channel.data.playersByAuthId[authId]
  channel.data.players.splice channel.data.players.indexOf(player), 1

  channel.logic.onPlayerRemoved player
  return

onLogInButtonClicked = ->
  document.getElementById('Overlay').classList.add 'Enabled'
  document.getElementById('LogInDialog').classList.add 'Active'

# Apps bar
onToggleMenuButtonClicked = (event) ->
  document.getElementById('AppsBar').classList.toggle 'Hidden'

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
onChatMessageReceived = (message) -> appendToChat message.text, channel.data.playersByAuthId[message.playerAuthId]  

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
  ChatLog.insertAdjacentHTML 'beforeend', JST['chatLogItem']( text: text, author: author, time: time )
  ChatLog.scrollTop = ChatLog.scrollHeight if isChatLogScrolledToBottom
  return
