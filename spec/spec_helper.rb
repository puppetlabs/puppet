dir = File.expand_path(File.dirname(__FILE__))

$LOAD_PATH.unshift("#{dir}/")
$LOAD_PATH.unshift("#{dir}/../lib")
$LOAD_PATH.unshift("#{dir}/../test/lib")  # Add the old test dir, so that we can still find our local mocha and spec

# include any gems in vendor/gems
Dir["#{dir}/../vendor/gems/**"].map do |path| 
    libpath = File.join(path, "lib")
    if File.directory?(libpath)
        $LOAD_PATH.unshift(libpath)
    else
        $LOAD_PATH.unshift(path)
    end
end

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

# load any monkey-patches
Dir["#{dir}/monkey_patches/*.rb"].map { |file| require file }
