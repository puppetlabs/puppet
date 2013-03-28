require 'puppet/pops/api'
require 'puppet/pops/impl'

require File.join(File.dirname(__FILE__), '/../factory_rspec_helper')

module ParserRspecHelper
  include FactoryRspecHelper
  def parse(code)
    parser = Puppet::Pops::Impl::Parser::Parser.new()
    parser.parse_string(code)
  end
end
