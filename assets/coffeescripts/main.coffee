usersElement = document.getElementById('Users')
currentStateElement = document.getElementById('CurrentState')
actorsElement = document.getElementById('Actors')

setupUser = (user) ->
  userElement = document.createElement 'li'
  userElement.id = 'User' + user.authId
  userElement.appendChild document.createTextNode user.displayName
  usersElement.appendChild userElement

setupActor = (actor) ->
  actorElement = document.createElement 'li'
  actorElement.id = 'Actor' + actor.authId
  actorElement.appendChild document.createTextNode actor.displayName
  actorsElement.appendChild actorElement

setupState = ->
  currentStateElement.textContent = channel.data.state

window.channel.logic =
  init: ->

    document.getElementById('JoinGame').addEventListener 'click', -> channel.socket.emit 'join'

    channel.socket.on 'addActor', (actor) ->
      return

    channel.socket.on 'removeActor', (authId) ->
      actor = channel.data.actorsByAuthId[authId]
      delete channel.data.actorsByAuthId[authId]
      channel.data.actors.splice channel.data.actors.indexOf(actor), 1

      document.getElementById('Actor' + actor.authId).remove()

      return

    channel.socket.on 'setState', (state) ->
      channel.data.state = state
      setupState()
  
  onChannelDataReceived: ->
    serverTimeOffset = Date.now() - channel.data.time
    channel.data.stateStartTime += serverTimeOffset if channel.data.stateStartTime?

    setupUser user for user in channel.data.users
    setupActor actor for actor in channel.data.actors
    setupState()

  onDisconnected: ->

  onUserAdded: (user) -> setupUser user
  onUserRemoved: (user) -> document.getElementById('User' + user.authId).remove()

  onActorAdded: (actor) -> setupActor actor
  onActorRemoved: (actor) -> document.getElementById('Actor' + actor.authId).remove()

