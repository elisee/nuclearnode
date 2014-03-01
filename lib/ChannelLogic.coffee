module.exports = class ChannelLogic

  @supportedStates = [
    'waitingForPlayers'
    'playing'
    'end'
  ]

  constructor: (@channel) ->
    @channel.public.settings =
      minPlayers: 1
      roundDuration: 10 * 1000
      endRoundDuration: 5 * 1000

    @setState 'waitingForPlayers'

  dispose: ->
    @channel = null

    # TODO: Cancel any intervals / timeouts you might have running
    clearTimeout @nextStateTimeoutId if @nextStateTimeoutId?


  #----------------------------------------------------------------------------
  # Channel events
  onSocketAdded: (socket) ->
    socket.actor = @channel.actorsByAuthId[socket.user.public.authId]

    # Message handlers for user actions
    socket.on 'join', =>
      return if socket.actor?

      socket.actor = actor =
        public:
          authId: socket.user.public.authId
          displayName: socket.user.public.displayName
          pictureURL: socket.user.public.pictureURL

      @channel.actorsByAuthId[actor.public.authId] = actor
      @channel.public.actors.push actor.public

      @channel.broadcast 'addActor', actor.public

      @startRound() if @channel.public.state == 'waitingForPlayers' and @channel.public.actors.length == @channel.public.settings.minPlayers
      return

    # socket.on 'action', =>

    return

  onSocketRemoved: (socket) ->
    socket.player = null

    # A user might be connected from multiple places so this event is rarely
    # useful. In most cases, we want to act only when the user is entirely
    # disconnected, i.e. when onUserLeft is fired

  onUserJoined: (user) ->
    return

  onUserLeft: (user) ->
    if user.actor?
      # The default behavior is to remove an actor as soon as the related user
      # is disconnected. In some games, it might make sense to keep them around
      # until the current round is over or simply allow reconnecting for a while
      delete @channel.actorsByAuthId[user.public.authId]
      @channel.public.actors.splice @channel.public.actors.indexOf(user.actor.public), 1
      @channel.broadcast 'removeActor', user.public.authId

    return


  #----------------------------------------------------------------------------
  # State management
  setState: (state) ->
    if ChannelLogic.supportedStates.indexOf(state) == -1
      @channel.log "Warning: undeclared state being set - #{state}"
    
    @channel.public.stateStartTime = Date.now()
    @channel.public.state = state
    @channel.broadcast 'setState', state

  startRound: ->
    @setState 'playing'
    @nextStateTimeoutId = setTimeout ( => @endRound() ), @channel.public.settings.roundDuration

  endRound: ->
    @setState 'end'
    @nextStateTimeoutId = setTimeout ( => @startRound() ), @channel.public.settings.endRoundDuration
