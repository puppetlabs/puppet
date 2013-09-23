require 'puppet/pops'
require 'puppet_spec/factory_rspec_helper'

module ParserRspecHelper
  include FactoryRspecHelper
  def parse(code)
    parser = Puppet::Pops::Parser::Parser.new()
    parser.parse_string(code)
  end
end
