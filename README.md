# NuclearNode

A node.js application template.

 * Built on [Express](http://expressjs.com/)
 * [CoffeeScript](http://coffeescript.org/) instead of JavaScript everywhere
 * [Jade](http://jade-lang.com/) & [jade-frakt](https://github.com/brikteknologier/jade-frakt) for server-side & client-side views
 * [Stylus](http://learnboost.github.io/stylus/) & [Nib](https://github.com/visionmedia/nib) for stylesheets
 * [Socket.IO](http://socket.io/) for real-time communication

## Getting started

 * Duplicate ``config.coffee.template`` as ``config.coffee`` and edit the file to suit your setup
 * Start up a [redis](http://redis.io/download) server to store session data
 * Install nodemon and CoffeeScript with ```npm install -g nodemon coffee-script```
 * Run ``npm install`` to install all dependencies
 * Run ``npm run nodemon`` to start a development server that will auto-restart whenever you make changes

## License

Do [whatever you want](http://www.wtfpl.net/) with this template, it's just boilerplate & I'm happy to share it. No credits or anything required.

If you improve on it, feel free to [submit pull requests](https://bitbucket.org/sparklinlabs/nuclearnode/). If you use it, feel free to [let me know](https://twitter.com/elisee).

## Future improvements

 * Look at using [asset-rack](https://github.com/techpines/asset-rack) or a similar library for serving static content
 * Add optional [Passport](http://passportjs.org/) support for authentication
