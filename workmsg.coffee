root = exports ? this

root.sizes =
   Tiny   : "XS"
   Small :  "S"
   Medium : "M"
   Large :  "L"
   XLarge : "XL"

# "name: aaa/nn, size: B, on: ccc"  -> [aaa, nn, B, ccc]
root.unpack = (input) ->
  p1 =  input.toString().replace( /\s/g, '')
  [label1, name, label2, size, label3, at]  =  p1.split /\:|,/g
  [name, size, at]

root.pack = (name, size, at) ->
  "name: #{name}, size: #{size}, at: #{at}"
