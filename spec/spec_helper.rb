dir = File.dirname(__FILE__)
$:.unshift("#{dir}/lib").unshift("#{dir}/../lib")

# Add the old test dir, so that we can still find mocha and spec
$:.unshift("#{dir}/../test/lib")

require 'mocha'
require 'puppettest'
require 'spec'

Spec::Runner.configure do |config|
  config.mock_with :mocha
  config.prepend_before :each do
      setup() if respond_to? :setup
  end

  config.prepend_after :each do
      teardown() if respond_to? :teardown
  end
end
