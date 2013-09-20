require 'puppet/pops'
require 'puppet/parser/ast'

require File.join(File.dirname(__FILE__), '/../factory_rspec_helper')

module TransformerRspecHelper
  include FactoryRspecHelper
  # Dumps the AST to string form
  #
  def astdump(ast)
    ast = transform(ast) unless ast.kind_of?(Puppet::Parser::AST)
    Puppet::Pops::Model::AstTreeDumper.new.dump(ast)
  end

  # Transforms the Pops model to an AST model
  #
  def transform(model)
    Puppet::Pops::Model::AstTransformer.new.transform(model)
  end

  # Parses the string code to a Pops model
  #
  def parse(code)
    parser = Puppet::Pops::Parser::Parser.new()
    parser.parse_string(code)
  end
end
