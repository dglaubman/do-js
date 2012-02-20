root = exports ? this

root.sizes =
   Small :  "S"
   Medium : "M"
   Large :  "L"
   XLarge : "XL"

# "name: aaa/nn, size: B, on: ccc"  -> [aaa, nn, B, ccc]
root.unpack = (input) ->
  p1 =  input.toString().replace( /\s/g, '')
  [label1, name, ver, label2, size, label3, at]  =  p1.split /\:|\/|,/g
  [name, ver, size, at]

root.pack = (name, ver, size, at) ->
  "name: #{name}/#{ver}, size: #{size}, at: #{at}"
