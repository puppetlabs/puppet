require 'puppet/pops'

module Puppet
module Parser
# Adapts an egrammar/eparser to respond to the public API of the classic parser
# and makes use of the new evaluator.
#
class E4ParserAdapter

  def initialize
    @file = ''
    @string = ''
    @use = :unspecified
  end

  def file=(file)
    @file = file
    @use = :file
  end

  def parse(string = nil)
    self.string= string if string
    parser = Pops::Parser::EvaluatingParser.singleton
    parse_result =
    if @use == :string
      # Parse with a source_file to set in created AST objects (it was either given, or it may be unknown
      # if caller did not set a file and the present a string.
      #
      parser.parse_string(@string, @file || "unknown-source-location")
    else
      parser.parse_file(@file)
    end

    # the parse_result may be
    # * empty / nil (no input)
    # * a Model::Program
    # * a Model::Expression
    #
    model = parse_result.nil? ? nil : parse_result.current
    args = {}
    Pops::Model::AstTransformer.new(@file).merge_location(args, model)

    ast_code =
    if model.is_a? Pops::Model::Program
      AST::PopsBridge::Program.new(model, args)
    else
      args[:value] = model
      AST::PopsBridge::Expression.new(args)
    end

    # Create the "main" class for the content - this content will get merged with all other "main" content
    AST::Hostclass.new('', :code => ast_code)
  end

  def string=(string)
    @string = string
    @use = :string
  end
end
end
end
