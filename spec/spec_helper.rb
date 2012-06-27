$:.insert(0, File.join([File.dirname(__FILE__), "..", "..", "lib"]))

require 'rubygems'
require 'rspec'
require 'puppetlabs_spec_helper/module_spec_helper'
require 'hiera/backend/puppet_backend'
require 'hiera/scope'
require 'rspec/mocks'
require 'mocha'

module ScopeSpecHelpers
  def hacked_scope
    scope = Puppet::Parser::Scope.new
    def scope.[](key); end
    scope
  end
end

RSpec.configure do |config|
  config.mock_with :mocha
  config.include ScopeSpecHelpers
end

