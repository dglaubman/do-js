mongodb = require("mongodb")

root = exports ? this
root.events =

  name: 'eventsrc'

  host: 'localhost'

  collection: 'signals'

  port: 27017

  insert: (entry, callback) ->
    @getCollection (collection) ->
      collection.insert entry

  getCollection: (callback) ->
    db = new mongodb.Db(@name, new mongodb.Server(@host, DB_PORT, {}, {}))
    db.open (error, client) ->
      console.error "Error with database: " + error  if error
      db.collection @collection, (error, collection) ->
        callback collection
        db.close()
