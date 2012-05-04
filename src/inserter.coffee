mongodb = require("mongodb")
root = exports ? this

root.inserter =
  host: 'localhost'
  collection: 'signals'
  name: 'journal'
  port: 27017

  insert: (entry) ->
    getCollection( this, (collection) -> collection.insert entry)

getCollection = (config, callback) ->
  db = new mongodb.Db(config.name, new mongodb.Server(config.host, config.port, {}, {}))
  db.open (error, client) ->
    console.error "Error with database: " + error  if error
    db.collection config.collection, (error, collection) ->
      callback collection
      db.close()
