window.channel.logic =
  init: ->
  
  onChannelDataReceived: ->
    serverTimeOffset = Date.now() - channel.data.time
    channel.data.stateStartTime += serverTimeOffset if channel.data.stateStartTime?

  onDisconnected: ->

  onPlayerAdded: (player) ->
  onPlayerRemoved: (player) ->