require 'puppet/pops'

module Puppet; module Parser; end; end;
# Adapts an egrammar/eparser to respond to the public API of the classic parser
# and makes use of the new evaluator.
#
class Puppet::Parser::E4ParserAdapter

  # Empty adapter fulfills watch_file contract without doing anything.
  # @api private
  class NullFileWatcher
    def watch_file(file)
      #nop
    end
  end

  # @param file_watcher [#watch_file] something that can watch a file
  def initialize(file_watcher = nil)
    @file_watcher = file_watcher || NullFileWatcher.new
    @file = ''
    @string = ''
    @use = :unspecified
    @@evaluating_parser ||= Puppet::Pops::Parser::EvaluatingParser.new()
  end

  def file=(file)
    @file = file
    @use = :file
    # watch if possible, but only if the file is something worth watching
    @file_watcher.watch_file(file) if !file.nil? && file != ''
  end

  def parse(string = nil)
    self.string= string if string

    if @file =~ /\.rb$/ && @use != :string
      # Will throw an error
      parse_ruby_file
    end

    parse_result =
    if @use == :string
      # Parse with a source_file to set in created AST objects (it was either given, or it may be unknown
      # if caller did not set a file and the present a string.
      #
      @@evaluating_parser.parse_string(@string, @file || "unknown-source-location")
    else
      @@evaluating_parser.parse_file(@file)
    end

    # the parse_result may be
    # * empty / nil (no input)
    # * a Model::Program
    # * a Model::Expression
    #
    model = parse_result.nil? ? nil : parse_result.current 
    args = {}
    Puppet::Pops::Model::AstTransformer.new(@file).merge_location(args, model)

    ast_code =
    if model.is_a? Puppet::Pops::Model::Program
      Puppet::Parser::AST::PopsBridge::Program.new(model, args)
    else
      args[:value] = model
      Puppet::Parser::AST::PopsBridge::Expression.new(args)
    end

    # Create the "main" class for the content - this content will get merged with all other "main" content
    Puppet::Parser::AST::Hostclass.new('', :code => ast_code)

  end

  def string=(string)
    @string = string
    @use = :string
  end

  def parse_ruby_file
    raise Puppet::ParseError, "Ruby DSL is no longer supported. Attempt to parse #{@file}"
  end
end
