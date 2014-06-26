path = require 'path'
config = require './config'

# Application
express = require 'express'
require 'express-expose'
app = express()

app.set 'port', config.internalPort
app.set 'views', path.join __dirname, 'views'
app.set 'view engine', 'jade'

env = app.get 'env'
baseURL = "http://#{config.domain}"
baseURL += ":#{config.publicPort}" if config.publicPort != 80

RedisStore = require('connect-redis')(express)
sessionStore = new RedisStore { db: config.redisDbIndex, ttl: 3600 * 24 * 14, prefix: "#{config.appId}sess:" }

app.expose
  appId: config.appId
  hubBaseURL: config.hubBaseURL
  public: config.public

# Authentication
passport = require 'passport'
passport.serializeUser (user, done) -> done null, user
passport.deserializeUser (obj, done) -> done null, obj

NuclearHubStrategy = require('passport-nuclearhub').Strategy
passport.use new NuclearHubStrategy
    appSecret: config.hubAppSecret
  , (data, done) ->
    done null,
      authId: data.authId
      displayName: data.displayName
      pictureURL: data.pictureURL
      serviceHandles: data.serviceHandles
      isGuest: data.isGuest
      isHubAdministrator: data.isHubAdministrator
      # FIXME: We should get that dynamically from the NuclearHub API, maybe even client-side
      apps: data.apps

# Middlewares
app.use express.logger('dev') if 'development' == env

app.use require('static-asset') __dirname + '/public/'
app.use express.static __dirname + '/public/'

app.use express.json()
app.use express.urlencoded()
app.use express.cookieParser config.sessionSecret
app.use express.session { key: "#{config.appId}.sid", cookie: { domain: '.' + config.domain, maxAge: 3600 * 24 * 14 * 1000 }, store: sessionStore }
app.use passport.initialize()
app.use passport.session()
require('nuclear-i18n')(app, [ 'common', 'nuclearnode' ])
app.use app.router

app.use express.errorHandler() if 'development' == env

# Create server
http = require 'http'
server = http.createServer app

# Socket.IO
socketio = require 'socket.io'
io = socketio.listen(server)

passportSocketIo = require 'passport.socketio'
io.set "authorization", passportSocketIo.authorize
  cookieParser: express.cookieParser
  key: "#{config.appId}.sid"
  secret: config.sessionSecret
  store: sessionStore
  fail: (data, err, critical, accept) -> accept null, true
  success: (data, accept) -> accept null, true

# Listen
engine = require './lib/engine'

engine.init app, io, ->
  server.listen app.get('port'), ->
    console.log "#{config.appId} server listening in #{env} mode on port " + app.get('port')

