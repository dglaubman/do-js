mongodb = require("mongodb")
root = exports ? this

database =
  host: 'localhost'
  collection: 'signals3'
  name: 'eventsrc'
  port: 27017

database.getCollection = (callback) ->
  db = new mongodb.Db(@name,
    new mongodb.Server(@host, @port, {}, {}))
  db.open (error, client) ->
    console.error "Error with database: " + error  if error
    db.collection database.collection, (error, collection) ->
      callback collection
      db.close()


database.insert = (entry) ->
  @getCollection (collection) ->
    collection.insert entry

root.database = database



