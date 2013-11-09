root = exports ? this

root.payloads = ( {data: {loss: n, event: 1},trail: [{ op: "scale", status: "ok"}] } for n in [ 1..10000 ] by 1000)
