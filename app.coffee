express = require 'express'
http = require 'http'
path = require 'path'
fs = require 'fs'
rack = require 'asset-rack'
nib = require 'nib'
expose = require 'express-expose'
RedisStore = require('connect-redis')(express)
socketio = require 'socket.io'
config = require './config'

app = express()

# All environments
app.set 'port', config.internalPort
app.set 'views', path.join( __dirname, 'views' )
app.set 'view engine', 'jade'

env = app.get 'env'
baseURL = "http://#{config.domain}"
baseURL += ":#{config.publicPort}" if config.publicPort != 80
sessionStore = new RedisStore { db: config.redisDbIndex, ttl: 3600 * 24 * 14, prefix: "#{config.appId}sess:" }

# Middlewares
if 'development' == env
  app.use express.logger('dev')

app.use express.json()
app.use express.urlencoded()
app.use express.cookieParser config.sessionSecret
app.use express.session { key: "#{config.appId}.sid", cookie: { domain: '.' + config.domain, maxAge: 3600 * 24 * 14 * 1000 }, store: sessionStore }

app.use new rack.Rack [
  new rack.StaticAssets { urlPrefix: '/static', dirname: './assets/static' }
  new rack.DynamicAssets { type: rack.StylusAsset, urlPrefix: '/stylesheets', dirname: './assets/stylesheets', options: { config: (stylus) -> stylus.set( 'compress', true ).use nib() } }
  new rack.JadeAsset { url: '/javascripts/templates.js', dirname: './templates' }
  new rack.SnocketsAsset { url: '/javascripts/app.js', filename: './assets/coffeescripts/app.coffee', compress: true }
]

app.use app.router

if 'development' == env
  app.use express.errorHandler()

# Routes
app.get '/', (req, res) -> res.render 'index'

# Create server
server = http.createServer(app)

# Socket.IO
io = socketio.listen(server)
io.set 'log level', 1

###
# (Enable this if you want passport.socketio authorization support)
io.set "authorization", passportSocketIo.authorize
  cookieParser: express.cookieParser
  key: "#{config.appId}.sid"
  secret: config.sessionSecret
  store: sessionStore
  fail: (data, err, critical, accept) -> accept null, !critical
  success: (data, accept) -> accept null, true
###

io.sockets.on 'connection', (socket) ->
  console.log "#{socket.id} (#{socket.handshake.address.address}) - connected"

  socket.on 'disconnect', ->
    console.log "#{socket.id} (#{socket.handshake.address.address}) - disconnected"

# Listen
server.listen app.get('port'), ->
  console.log 'Server listening on port ' + app.get('port')
