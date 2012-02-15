root = exports ? this

root.loads = { L : "Low", M : "Moderate", H: "High" }

# Publish server ready and current load every interval millisecs
root.heartbeat = ( conn, topic, pname, interval = 5000, load = root.loads.L ) ->
  exchange = conn.exchange 'servers', options = { type: 'topic', autodelete: false }, ->
    setInterval ( ->
      exchange.publish topic, "name: #{pname}, load: #{load}"
      ) , interval



