$:.insert(0, File.join([File.dirname(__FILE__), "..", "..", "lib"]))

require 'rubygems'
require 'rspec'
require 'hiera/backend/puppet_backend'
require 'hiera/scope'
require 'rspec/mocks'
require 'mocha'

RSpec.configure do |config|
    config.mock_with :mocha
end

class Puppet
    class Parser
        class Functions
        end
    end
end

