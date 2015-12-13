require 'puppet/pops'

require File.join(File.dirname(__FILE__), '/../factory_rspec_helper')

module ParserRspecHelper
  include FactoryRspecHelper

  def with_app_management(flag)
    Puppet[:app_management] = flag
  end

  def parse(code)
    parser = Puppet::Pops::Parser::Parser.new()
    parser.parse_string(code)
  end

  def parse_epp(code)
    parser = Puppet::Pops::Parser::EppParser.new()
    parser.parse_string(code)
  end
end
