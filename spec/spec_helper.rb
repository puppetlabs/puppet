dir = File.expand_path(File.dirname(__FILE__))

$LOAD_PATH.unshift("#{dir}/")
$LOAD_PATH.unshift("#{dir}/lib") # a spec-specific test lib dir
$LOAD_PATH.unshift("#{dir}/../lib")
$LOAD_PATH.unshift("#{dir}/../test/lib")  # Add the old test dir, so that we can still find our local mocha and spec

# include any gems in vendor/gems
Dir["#{dir}/../vendor/gems/**"].each do |path|
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
gem 'rspec', '=1.2.9'
require 'spec/autorun'

# So everyone else doesn't have to include this base constant.
module PuppetSpec
end

# load any monkey-patches
Dir["#{dir}/monkey_patches/*.rb"].map { |file| require file }

Spec::Runner.configure do |config|
    config.mock_with :mocha

#  config.prepend_before :all do
#      setup_mocks_for_rspec
#      setup() if respond_to? :setup
#  end
#
    config.prepend_after :each do
        Puppet.settings.clear
        Puppet::Node::Environment.clear
    end
end

# Set the confdir and vardir to gibberish so that tests
# have to be correctly mocked.
Puppet[:confdir] = "/dev/null"
Puppet[:vardir] = "/dev/null"

# We need this because the RAL uses 'should' as a method.  This
# allows us the same behaviour but with a different method name.
class Object
    alias :must :should
end
