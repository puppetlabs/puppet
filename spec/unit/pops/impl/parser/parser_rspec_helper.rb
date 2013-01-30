require 'puppet/pops/api'
require 'puppet/pops/api/model/model'
require 'puppet/pops/impl/model/factory'
require 'puppet/pops/impl/model/model_tree_dumper'
require 'puppet/pops/impl/parser/eparser'
require 'puppet/pops/impl/top_scope'
require File.join(File.dirname(__FILE__), '/../factory_rspec_helper')

module ParserRspecHelper
  include FactoryRspecHelper
  
  def parse(code)
    parser = Puppet::Pops::Impl::Parser::Parser.new()
    parser.parse_string(code)
  end
end