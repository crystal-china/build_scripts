require "xml"

document = XML.parse("<hello>world</hello>")
puts "XML OK: #{document.root.not_nil!.content}"
