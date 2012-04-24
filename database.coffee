mongodb = require("mongodb")
root = exports ? this

DB_PORT = 27017
host = 'localhost'
collection = 'signals'
name = 'eventsrc'

getCollection = (callback) ->
  db = new mongodb.Db(name, new mongodb.Server(host, DB_PORT, {}, {}))
  db.open (error, client) ->
    console.error "Error with database: " + error  if error
    db.collection collection, (error, collection) ->
      callback collection
      db.close()

root.database = {}

root.database.insert = (entry) ->
  getCollection (collection) ->
    collection.insert entry



