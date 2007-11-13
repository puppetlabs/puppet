dir = File.expand_path(File.dirname(__FILE__))
$LOAD_PATH.unshift("#{dir}/lib")
$LOAD_PATH.unshift("#{dir}/../lib")
$LOAD_PATH.unshift("#{dir}/../test/lib")  # Add the old test dir, so that we can still find our local mocha and spec

require 'puppettest'
require 'puppettest/runnable_test'
require 'mocha'
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

require "#{dir}/lib/monkey_patches/add_confine_and_runnable_to_rspec_dsl"
