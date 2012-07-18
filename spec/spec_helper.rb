$LOAD_PATH.insert(0, File.join([File.dirname(__FILE__), "..", "..", "lib"]))

require 'rubygems'
require 'rspec'
require 'rspec/mocks'
require 'hiera'
require 'puppetlabs_spec_helper/module_spec_helper'
require 'hiera_puppet'
require 'hiera/backend/puppet_backend'
require 'hiera/scope'

RSpec.configure do |config|
  config.mock_with :mocha
end
