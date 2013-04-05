require 'puppet/pops'

module Puppet; module Parser; end; end;
# Adapts an egrammar/eparser to respond to the public API of the classic parser
#
class Puppet::Parser::EParserAdapter

  def initialize(classic_parser)
    @classic_parser = classic_parser
    @file = ''
    @string = ''
    @use = :undefined
  end

  def file=(file)
    @classic_parser.file = file
    @file = file
    @use = :file
  end

  def parse(string = nil)
    if @file =~ /\.rb$/
      return parse_ruby_file
    else
      self.string= string if string
      parser = Puppet::Pops::Parser::Parser.new()
      parse_result = if @use == :string
        parser.parse_string(@string)
      else
        parser.parse_file(@file)
      end
      # Compute the source_file to set in created AST objects (it was either given, or it may be unknown
      # if caller did not set a file and the present a string.
      #
      source_file = @file || "unknown-source-location"

      # Validate
      validate(parse_result)

      # Transform the result, but only if not nil
      parse_result = Puppet::Pops::Model::AstTransformer.new(source_file, @classic_parser).transform(parse_result) if parse_result
      if parse_result && !parse_result.is_a?(Puppet::Parser::AST::BlockExpression)
        # Need to transform again, if result is not wrapped in something iterable when handed off to
        # a new Hostclass as its code.
        parse_result = Puppet::Parser::AST::BlockExpression.new(:children => [parse_result]) if parse_result
      end
    end

    Puppet::Parser::AST::Hostclass.new('', :code => parse_result)
  end

  def validate(parse_result)
    # TODO: This is too many hoops to jump through... ugly API
    # could reference a ValidatorFactory.validator_3_1(acceptor) instead.
    # and let the factory abstract the rest.
    #
    return unless parse_result

    acceptor  = Puppet::Pops::Validation::Acceptor.new
    validator = Puppet::Pops::Validation::ValidatorFactory_3_1.new().validator(acceptor)
    validator.validate(parse_result)

    max_errors = Puppet[:max_errors]
    max_warnings = Puppet[:max_warnings] + 1
    max_deprecations = Puppet[:max_deprecations] + 1

    # If there are warnings output them
    warnings = acceptor.warnings
    if warnings.size > 0
      formatter = Puppet::Pops::Validation::DiagnosticFormatterPuppetStyle.new
      emitted_w = 0
      emitted_dw = 0
      acceptor.warnings.each {|w|
        if w.severity == :deprecation
          # Do *not* call Puppet.deprecation_warning it is for internal deprecation, not
          # deprecation of constructs in manifests! (It is not designed for that purpose even if
          # used throughout the code base).
          #
          Puppet.warning(formatter.format(w)) if emitted_dw < max_deprecations
          emitted_dw += 1
        else
          Puppet.warning(formatter.format(w)) if emitted_w < max_warnings
          emitted_w += 1
        end
        break if emitted_w > max_warnings && emitted_dw > max_deprecations # but only then
      }
    end

    # If there were errors, report the first found. Use a puppet style formatter.
    errors = acceptor.errors
    if errors.size > 0
      formatter = Puppet::Pops::Validation::DiagnosticFormatterPuppetStyle.new
      if errors.size == 1 || max_errors <= 1
        # raise immediately
        raise Puppet::ParseError.new(formatter.format(errors[0]))
      end
      emitted = 0
      errors.each do |e|
        Puppet.err(formatter.format(e))
        emitted += 1
        break if emitted >= max_errors
      end
      warnings_message = warnings.size > 0 ? ", and #{warnings.size} warnings" : ""
      giving_up_message = "Found #{errors.size} errors#{warnings_message}. Giving up"
      exception = Puppet::ParseError.new(giving_up_message)
      exception.file = errors[0].file
      raise exception
    end
  end

  def string=(string)
    @classic_parser.string = string
    @string = string
    @use = :string
  end

  def parse_ruby_file
    @classic_parser.parse
  end
end
