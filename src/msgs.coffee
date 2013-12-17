root = exports ? this

root.Dot =
  Topic: 'dot.ready'
  Message: (sender, dot, rak) ->
    "sender|#{sender}|dot|#{dot}|rak|#{rak}"

