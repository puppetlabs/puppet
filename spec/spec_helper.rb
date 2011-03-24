require 'pathname'
dir = Pathname.new(__FILE__).parent
$LOAD_PATH.unshift(dir, dir + 'lib', dir + '../lib')

require 'mocha'
require 'puppet'
require 'puppet/interface'
require 'rspec'

RSpec.configure do |config|
    config.mock_with :mocha

    config.before :each do
      # Set the confdir and vardir to gibberish so that tests
      # have to be correctly mocked.
      Puppet[:confdir] = "/dev/null"
      Puppet[:vardir] = "/dev/null"

      # Avoid opening ports to the outside world
      Puppet.settings[:bindaddress] = "127.0.0.1"

      @logs = []
      Puppet::Util::Log.newdestination(@logs)
    end

    config.after :each do
      Puppet.settings.clear

      @logs.clear
      Puppet::Util::Log.close_all
    end
end

# We need this because the RAL uses 'should' as a method.  This
# allows us the same behaviour but with a different method name.
class Object
    alias :must :should
end
