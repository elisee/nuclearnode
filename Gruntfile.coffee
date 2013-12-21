module.exports = (grunt) ->
  grunt.loadNpmTasks 'grunt-contrib-jade'
  grunt.loadNpmTasks 'grunt-contrib-stylus'
  grunt.loadNpmTasks 'grunt-contrib-coffee'
  grunt.loadNpmTasks 'grunt-contrib-uglify'
  grunt.loadNpmTasks 'grunt-contrib-watch'

  grunt.initConfig
    jade:
      compile:
        options: { client: true, processName: (filename) -> filename.substring( 'assets/templates/'.length, filename.indexOf('.jade') ) }
        files:
          'assets/templates/templates.js': [ 'assets/templates/**/*.jade' ]
    stylus:
      compile:
        files: [
          expand: true
          cwd: 'assets/stylesheets'
          src: ['**/*.styl']
          dest: 'public/css'
          ext: '.css'
        ]
    coffee:
      compile:
        files:[
          expand: true
          cwd: 'assets/coffeescripts'
          src: ['**/*.coffee']
          dest: 'public/js'
          ext: '.js'
        ]
    uglify:
      jadeRuntime:
        files:
          'public/js/templates.js': [ 'node_modules/jade/runtime.js', 'assets/templates/templates.js' ]
      compile:
        files: [
          expand: true
          cwd: 'public/js'
          src: ['**/*.js']
          dest: 'public/js'
          ext: '.js'
        ]
    watch:
      templates:
        files: [ 'assets/templates/**/*.jade' ]
        tasks: [ 'jade' ]
      stylesheets:
        files: [ 'assets/stylesheets/**/*.styl' ]
        tasks: [ 'stylus' ]
      scripts:
        files: [ 'assets/coffeescripts/**/*.coffee' ]
        tasks: [ 'coffee' ]
  
  grunt.registerTask 'default', [ 'jade', 'stylus', 'coffee', 'uglify' ]
  grunt.registerTask 'dev', [ 'jade', 'stylus', 'coffee', 'uglify:jadeRuntime', 'watch' ]
