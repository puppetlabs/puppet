require 'puppet/pops/api/model/model'
require 'puppet/pops/api/validation'

require 'puppet/pops/impl/parser/eparser'
require 'puppet/pops/impl/model/ast_transformer'
require 'puppet/pops/impl/model/ast_tree_dumper'
require 'puppet/pops/impl/validation/validator_factory_3_1'

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
    #      # Uncomment this block to also parse using the classoc parser (enables comparison at the end).
    #      # But be careful, this means parsing the same file twice which does not always work (creates duplicates).
    #      begin
    #      classic_result = @classic_parser.parse(string)
    #      rescue
    #        # May fail to parse new syntax
    #        classic_result = nil
    #      end
    if @file =~ /\.rb$/
      return parse_ruby_file
    else
      self.string= string if string
      parser = Puppet::Pops::Impl::Parser::Parser.new()
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
      begin
        validate(parse_result)
      rescue => e
        # This rescue is here for debugging purposes (if there is a fundamental issue rather than one that
        # should be reported.
        raise e
      end

      # Transform the result, but only if not nil
      parse_result = Puppet::Pops::Impl::Model::AstTransformer.new(source_file, @classic_parser).transform(parse_result) if parse_result
      if parse_result && !parse_result.is_a?(Puppet::Parser::AST::BlockExpression)
        # Need to transform again, if result is not wrapped in something iterable when handed off to
        # a new Hostclass as its code.
        parse_result = Puppet::Parser::AST::BlockExpression.new(:children => [parse_result]) if parse_result
      end
    end
    #      # DEBUGGING OUTPUT
    #      # See comment at entry of method to also parse using classic parser
    #      #
    #      original_result = Puppet::Pops::Impl::Model::AstTreeDumper.new().dump(classic_result)
    #      converted_result = Puppet::Pops::Impl::Model::AstTreeDumper.new().dump(parse_result)
    ##      puts "Classic:\n" + original_result
    ##      converted = puts "Converted:\n" + converted_result

    result = Puppet::Parser::AST::Hostclass.new('', :code => parse_result)

    #      # DEBUGGING COMPARISION
    #      final_result = Puppet::Pops::Impl::Model::AstTreeDumper.new().dump(result)
    #      if final_result != original_result
    #        puts "Classic:\n" + original_result
    #        puts "Final:\n" + final_result
    #        debugger
    #        puts "Classic and final result differs"
    #      end
    result
  end

  def validate(parse_result)
    # TODO: This is too many hoops to jump through... ugly API
    # could reference a ValidatorFactory.validator_3_1(acceptor) instead.
    # and let the factory abstract the rest.
    #
    return unless parse_result

    acceptor  = Puppet::Pops::API::Validation::Acceptor.new
    validator = Puppet::Pops::Impl::Validation::ValidatorFactory_3_1.new().validator(acceptor)
    validator.validate(parse_result)

    max_errors = Puppet[:max_errors]
    max_warnings = Puppet[:max_warnings]

    # If there are warnings output all of them
    warnings = acceptor.warnings
    if warnings.size > 0
      formatter = Puppet::Pops::API::Validation::DiagnosticFormatterPuppetStyle.new
      emitted = 0      
      acceptor.warnings.each {|w|
        # TODO: if diagnostic is a deprecation, call Puppet.deprecation_warning instead 
        Puppet.warning(formatter.format(w))
        emitted += 1
        break if emitted > max_warnings
      }
    end

    # If there were errors, report the first found. Use a puppet style formatter.
    errors = acceptor.errors
    if errors.size > 0
      formatter = Puppet::Pops::API::Validation::DiagnosticFormatterPuppetStyle.new
      if errors.size == 1 || max_errors <= 1
        # raise immediately
        raise Puppet::ParseError.new(formatter.format(errors[0]))
      end
      emitted = 0
      errors.each {|e| 
        Puppet.err(formatter.format(e))
        emitted += 1
        break if emitted >= max_errors
      }
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
