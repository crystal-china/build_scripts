require "xml"

document = XML.parse("<hello>world</hello>")
puts "macOS XML OK: #{document.root.not_nil!.content}"
