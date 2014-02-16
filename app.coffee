path = require 'path'
fs = require 'fs'
config = require './config'

# Application
express = require 'express'
expose = require 'express-expose'
app = express()

app.set 'port', config.internalPort
app.set 'views', path.join __dirname, 'views'
app.set 'view engine', 'jade'

env = app.get 'env'
baseURL = "http://#{config.domain}"
baseURL += ":#{config.publicPort}" if config.publicPort != 80

RedisStore = require('connect-redis')(express)
sessionStore = new RedisStore { db: config.redisDbIndex, ttl: 3600 * 24 * 14, prefix: "#{config.appId}sess:" }

# Authentication
passport = require 'passport'
passport.serializeUser (user, done) -> done null, user
passport.deserializeUser (obj, done) -> done null, obj

# TODO: Install and uncomment the passport strategies you want to use

###
TwitterStrategy = require('passport-twitter').Strategy
passport.use new TwitterStrategy
    consumerKey: config.twitter.consumerKey,
    consumerSecret: config.twitter.consumerSecret
    callbackURL: baseURL + "/auth/twitter/callback"
  , (token, tokenSecret, profile, done) ->
    done null, 
      authId: "twitter#{profile._json.id_str}"
      twitterId: profile._json.id_str
      twitterHandle: profile.username
      displayName: profile.displayName
      pictureURL: profile.photos[0].value
      twitterToken: token
      twitterTokenSecret: tokenSecret
###

###
TwitchtvStrategy = require('passport-twitchtv').Strategy
passport.use new TwitchtvStrategy
    clientID: config.twitchtv.clientID,
    clientSecret: config.twitchtv.clientSecret
    callbackURL: baseURL + "/auth/twitchtv/callback"
  , (accessToken, refreshToken, profile, done) ->
    done null, 
      authId: "twitchtv#{profile._json._id.toString()}",
      twitchtvId: profile._json._id.toString()
      twitchtvHandle: profile.username.toLowerCase()
      displayName: profile._json.display_name
      pictureURL: profile._json.logo
      twitchtvToken: accessToken
      twitchtvRefreshToken: refreshToken
###

###
LocalStrategy = require('passport-local').Strategy
passport.use new LocalStrategy (username, password) ->
  # TODO: Validate username & password
  return done null, false if ! ...

  done null, authId: "local#{username}"
###

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
require('./lib/i18n')(app)
app.use app.router

app.use express.errorHandler() if 'development' == env

# Routes
app.get '/', (req, res) -> res.render 'index'

#app.get '/auth/twitter', passport.authenticate 'twitter'
#app.get '/auth/twitter/callback', passport.authenticate 'twitter', { successReturnToOrRedirect: '/', failureRedirect: '/' }
app.get '/logout', (req, res) -> req.logout(); res.redirect '/'

# Create server
http = require 'http'
server = http.createServer app

# Socket.IO
socketio = require 'socket.io'

io = socketio.listen(server)
io.set 'log level', 1
io.set 'transports', [ 'websocket' ]

passportSocketIo = require 'passport.socketio'
io.set "authorization", passportSocketIo.authorize
  cookieParser: express.cookieParser
  key: "#{config.appId}.sid"
  secret: config.sessionSecret
  store: sessionStore
  fail: (data, err, critical, accept) -> accept null, !critical
  success: (data, accept) -> accept null, true

io.sockets.on 'connection', (socket) ->
  console.log "#{socket.id} (#{socket.handshake.address.address}) - connected"

  socket.on 'disconnect', ->
    console.log "#{socket.id} (#{socket.handshake.address.address}) - disconnected"

# Listen
server.listen app.get('port'), ->
  console.log "#{config.appId} server listening on port " + app.get('port')
