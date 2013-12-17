root = exports ? this

{logger, trace,log, error} = require './log'

root.store =

  init: (argv) ->
    unless argv.db
      return (arga...) ->
        try
          trace arga
        catch e
          error e

    name       = argv.db         if argv.db
    host       = argv.dbhost     or 'localhost'
    port       = argv.dbport     or 27017
    collection = argv.collection if 'losses'
    mongodb = require("mongodb")

    getCollection = (config, callback) ->
      db = new mongodb.Db(name, new mongodb.Server(host, port, {}, {}))
      db.open (error, client) ->
        console.error "Error with database: " + error  if error
        db.collection collection, (error, collection) ->
          callback collection
          db.close()

    return (entry) ->
      getCollection( this, (collection) -> collection.insert entry)

