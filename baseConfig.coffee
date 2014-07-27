module.exports =
  # Logging level (debug: 0, info: 1, warning: 2, error: 3)
  logLevel: 2

  # Channel configuration
  channels:
    # URL prefix for channels
    prefix: "play"
    # Services which can be used to create username-based channels
    # null allows creating channels without any authentication service
    services: [ null, 'twitch', 'twitter' ] # 'steam', 'facebook', 'google'
    # Limit the number of users who can join a channel. Others will be shown stream / info message
    maxUsers: 100

  # Global *public* data, will be exposed to the client as window.app.public
  public:
    adwords:
      client: "ca-pub-1755908062252241"
      slot300x250: "8738164039"
    joinPartMaxUsers: 20
