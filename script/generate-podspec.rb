require 'erubis'

template = File.read(File.dirname(__FILE__) + "/GCUIKit.podspec.erb")
template = Erubis::Eruby.new(template)
puts template.result(:version => ARGV[0])
