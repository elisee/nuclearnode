module.exports = class ChannelLogic
  @supportedStates = [
    'waitingForPlayers'
    'playing'
    'end'
  ]

  constructor: (@channel) ->
    @channel.public.players = []

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
    # TODO: Register message handlers for player actions
    # socket.on 'action', ->

  onSocketRemoved: (socket) ->

  onPlayerJoined: (player) ->
    @channel.public.players.push player.public
    @startRound() if @channel.public.state == 'waitingForPlayers' and @channel.public.players.length == @channel.public.settings.minPlayers

  onPlayerLeft: (player) ->
    @channel.public.players.splice @channel.public.players.indexOf(player.public), 1

  #----------------------------------------------------------------------------
  # State management
  setState: (state) ->
    if ChannelLogic.supportedStates.indexOf(state) == -1
      @channel.log "Warning: unsupported game state being set - #{state}"
    
    @channel.public.stateStartTime = Date.now()
    @channel.public.state = state
    @channel.broadcast 'setState', state

  startRound: ->
    @setState 'playing'
    @nextStateTimeoutId = setTimeout ( => @endRound() ), @channel.public.settings.roundDuration

  endRound: ->
    @setState 'end'
    @nextStateTimeoutId = setTimeout ( => @startRound() ), @channel.public.settings.endRoundDuration
