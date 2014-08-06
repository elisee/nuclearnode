config = require './config'

gulp = require 'gulp'
gutil = require 'gulp-util'
jade = require 'gulp-jade'
concat = require 'gulp-concat'
header = require 'gulp-header'
stylus = require 'gulp-stylus'
nib = require 'nib'
coffee = require 'gulp-coffee'
uglify = require 'gulp-uglify'
cson = require 'gulp-cson'
fs = require 'fs'

paths =
  scripts:
    src: './assets/coffeescripts/**/*.coffee'
    dest: './public/js'
  templates:
    src: './assets/templates/**/*.jade'
    dest: './public/js'
  styles:
    src: './assets/stylesheets/**/*.styl'
    dest: 'public/css'
  locales:
    src: './assets/locales/**/*.cson'
    dest: './public/locales'

gulp.task 'scripts', ->
  stream = gulp
    .src paths.scripts.src
    .pipe coffee()
    .on 'error', gutil.log

  if ! config.disableUglify
    stream = stream.pipe uglify()

  stream.pipe gulp.dest paths.scripts.dest

templateHeader = fs.readFileSync('./node_modules/jade/runtime.js', 'utf8') + '\nvar JST = {};\n'
through = require 'through2'
path = require 'path'

fixTemplateFunctionName = (rootPath) ->
  transform = (file, enc, callback) ->
    unless file.isBuffer()
      @push file
      callback()
      return

    filePath = file.path.substring 0, file.path.length - ".js".length
    pathParts = path.relative( rootPath, filePath ).split(path.sep)
    templateName = pathParts.join '/'
    funcName = pathParts.join '_'

    from = "function template(locals) {"
    to = "JST['#{templateName}'] = function #{funcName}(locals) {"
    contents = file.contents.toString().replace from, to
    file.contents = new Buffer contents
    @push file
    callback()
    return
  through.obj transform

gulp.task 'templates', ->
  stream = gulp
    .src paths.templates.src
    .pipe jade client: true
    .pipe fixTemplateFunctionName './assets/templates'
    .pipe concat 'templates.js'
    .pipe header templateHeader

  if ! config.disableUglify
    stream = stream.pipe uglify()

  stream.pipe gulp.dest paths.templates.dest

gulp.task 'styles', ->
  gulp
    .src paths.styles.src
    .pipe stylus use: [ nib() ], errors: true
    .pipe gulp.dest paths.styles.dest

gulp.task 'locales', ->
  gulp
    .src paths.locales.src
    .pipe cson()
    .pipe gulp.dest paths.locales.dest

tasks = [ 'scripts', 'templates', 'styles', 'locales' ]

gulp.task 'watch', tasks, ->
  gulp.watch paths.scripts.src, ['scripts']
  gulp.watch paths.styles.src, ['styles']
  gulp.watch paths.templates.src, ['templates']
  gulp.watch paths.locales.src, ['locales']

gulp.task 'default', tasks
