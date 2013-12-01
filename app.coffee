express = require 'express'
http = require 'http'
path = require 'path'
stylus = require 'stylus'
nib = require 'nib'
expose = require 'express-expose'
frakt = require 'jade-frakt'
RedisStore = require('connect-redis')(express)
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
app.use app.router
app.use stylus.middleware src: __dirname + '/public', compile: (str, path) ->
  stylus(str).set('filename', path).set('compress', true).use nib()
app.use require('express-coffee')(
    path: path.join( __dirname, 'public' )
    live: env != 'production'
    uglify: env == 'production'
    debug: env != 'production'
  )
app.use frakt __dirname + '/clientTemplates', compile: true, expose: true
app.use stylus.middleware src: __dirname + '/public', compile: (str, path) -> stylus(str).set('filename', path).set('compress', true).use nib()
app.use express.static path.join(__dirname, 'public')

if 'development' == env
  app.use express.errorHandler()

# Routes
app.get '/', (req, res) -> res.render 'index'

# Listen
http.createServer(app).listen app.get('port'), ->
  console.log 'Server listening on port ' + app.get('port')
