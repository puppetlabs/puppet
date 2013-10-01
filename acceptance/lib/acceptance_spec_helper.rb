require 'fileutils'

dir = File.expand_path(File.dirname(__FILE__))
$LOAD_PATH.unshift dir

RSpec.configure do |config|
  config.mock_with :mocha
end
