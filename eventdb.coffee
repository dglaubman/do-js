semver = "0.1.1"

amqp = require('amqp')
mongodb = require("mongodb")
console = require('./log').log
config = require('./config')
argv = require('optimist').argv

error = (err) -> logger.log err
fatal = (err) ->
  error err
  process.exit 0

host = argv.host     or 'localhost'
suffix = argv.suffix or ''

logger.verbose = argv.v
logger.log "eventlog: version #{semver}"

dbname = argv.db || 'eventsrc'
dbhost = argv.dbhost || 'localhost'
dbport = argv.dbport || 27017
collection = argv.collection || 'signals'

vhost = argv.vhost || ('v' + semver)
host = argv.host || 'localhost'

xsignal = argv.xsignal || 'da
connection = amqp.createConnection( { host: host, vhost: vhost } )
connection.on 'ready', ->
  signalX = connection.exchange xsignal, options =
    type: 'topic'
    autodelete: false

  insert: (entry) ->
    @getCollection (collection) ->
      collection.insert entry

  getCollection: (callback) ->
    db = new mongodb.Db(@name, new mongodb.Server(@host, DB_PORT, {}, {}))
    db.open (error, client) ->
      console.error "Error with database: " + error  if error
      db.collection @collection, (error, collection) ->
        callback collection
        db.close()
