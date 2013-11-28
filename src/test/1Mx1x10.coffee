root = exports ? this

root.payloads = ( [ {loss: n, event: 1}]  for n in [ 1..10000000 ] by 1000000)
# console.log root.payloads