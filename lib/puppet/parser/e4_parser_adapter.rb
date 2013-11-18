require 'puppet/pops'

module Puppet; module Parser; end; end;
# Adapts an egrammar/eparser to respond to the public API of the classic parser
# and makes use of the new evaluator.
#
class Puppet::Parser::E4ParserAdapter

  def initialize()
    @file = ''
    @string = ''
    @use = :undefined
    @@evaluating_parser ||= Puppet::Pops::Parser::EvaluatingParser::Transitional.new()
  end

  def file=(file)
    @file = file
    @use = :file
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

#  # TODO: This is unsused as the validating parser is used instead
#  # Remove this method ?
#  def validate(parse_result)
#    # TODO: This is too many hoops to jump through... ugly API
#    # could reference a ValidatorFactory.validator_3_1(acceptor) instead.
#    # and let the factory abstract the rest.
#    #
#    return unless parse_result
#
#    acceptor  = Puppet::Pops::Validation::Acceptor.new
#    validator = Puppet::Pops::Validation::ValidatorFactory_3_1.new().validator(acceptor)
#    validator.validate(parse_result)
#
#    max_errors = Puppet[:max_errors]
#    max_warnings = Puppet[:max_warnings] + 1
#    max_deprecations = Puppet[:max_deprecations] + 1
#
#    # If there are warnings output them
#    warnings = acceptor.warnings
#    if warnings.size > 0
#      formatter = Puppet::Pops::Validation::DiagnosticFormatterPuppetStyle.new
#      emitted_w = 0
#      emitted_dw = 0
#      acceptor.warnings.each {|w|
#        if w.severity == :deprecation
#          # Do *not* call Puppet.deprecation_warning it is for internal deprecation, not
#          # deprecation of constructs in manifests! (It is not designed for that purpose even if
#          # used throughout the code base).
#          #
#          Puppet.warning(formatter.format(w)) if emitted_dw < max_deprecations
#          emitted_dw += 1
#        else
#          Puppet.warning(formatter.format(w)) if emitted_w < max_warnings
#          emitted_w += 1
#        end
#        break if emitted_w > max_warnings && emitted_dw > max_deprecations # but only then
#      }
#    end
#
#    # If there were errors, report the first found. Use a puppet style formatter.
#    errors = acceptor.errors
#    if errors.size > 0
#      formatter = Puppet::Pops::Validation::DiagnosticFormatterPuppetStyle.new
#      if errors.size == 1 || max_errors <= 1
#        # raise immediately
#        raise Puppet::ParseError.new(formatter.format(errors[0]))
#      end
#      emitted = 0
#      errors.each do |e|
#        Puppet.err(formatter.format(e))
#        emitted += 1
#        break if emitted >= max_errors
#      end
#      warnings_message = warnings.size > 0 ? ", and #{warnings.size} warnings" : ""
#      giving_up_message = "Found #{errors.size} errors#{warnings_message}. Giving up"
#      exception = Puppet::ParseError.new(giving_up_message)
#      exception.file = errors[0].file
#      raise exception
#    end
#  end

  def string=(string)
    @string = string
    @use = :string
  end

  def parse_ruby_file
    raise Puppet::ParseError, "Ruby DSL is no longer supported. Attempt to parse #{@file}"
  end
end
