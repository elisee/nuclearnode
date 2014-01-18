path = require 'path'
fs = require 'fs'
config = require './config'

# Application
express = require 'express'
expose = require 'express-expose'
app = express()

app.set 'port', config.internalPort
app.set 'views', path.join( __dirname, 'views' )
app.set 'view engine', 'jade'

env = app.get 'env'
baseURL = "http://#{config.domain}"
baseURL += ":#{config.publicPort}" if config.publicPort != 80

RedisStore = require('connect-redis')(express)
sessionStore = new RedisStore { db: config.redisDbIndex, ttl: 3600 * 24 * 14, prefix: "#{config.appId}sess:" }

# Middlewares
app.use express.logger('dev') if 'development' == env

app.use require('static-asset') __dirname + '/public/'
app.use express.static __dirname + '/public/'

app.use express.json()
app.use express.urlencoded()
app.use express.cookieParser config.sessionSecret
app.use express.session { key: "#{config.appId}.sid", cookie: { domain: '.' + config.domain, maxAge: 3600 * 24 * 14 * 1000 }, store: sessionStore }
require('./lib/i18n')(app)

app.use app.router

app.use express.errorHandler() if 'development' == env

# Routes
app.get '/', (req, res) -> res.render 'index'

# Create server
http = require 'http'
server = http.createServer(app)

# Socket.IO
socketio = require 'socket.io'

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
