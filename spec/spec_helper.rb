dir = File.dirname(__FILE__)
$:.unshift("#{dir}/lib").unshift("#{dir}/../lib")

# Add the old test dir, so that we can still find mocha and spec
$:.unshift("#{dir}/../test/lib")

require 'mocha'
require 'spec'
require 'puppettest'

Spec::Runner.configure do |config|
  config.mock_with :mocha
end
