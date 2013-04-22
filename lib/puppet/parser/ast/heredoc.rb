require 'puppet/parser/ast/branch'

class Puppet::Parser::AST
  # Evaluates its single text expression.
  # In addition to producing a string Heredoc also validates the produced string if
  # syntax has been set and there is a function available for validation.
  # If no function is available validation is silently skipped. (TODO: Decide if this is ok
  # or needs a setting).
  #
  # Unfortunately it is not possible to validate all strings at parse time (they may contain
  # interpolated expressions) and thus a scope is required. This means validation errors go
  # undetected until the string is evaluated. (It is at least validated before it is placed
  # in the catalog, fed as content to a file that at some time later may fail because of the
  # validation error).
  #
  # Possible Improvements:
  # * validate string at parse time if string is static.
  # * compute positions in lexer for slurped/escaped sequences and margins to enable correct
  #   positioning information in output from checker.
  #
  class Heredoc < AST::Leaf

    # @return [String, nil] the name of the syntax of the contained text expr
    attr_accessor :syntax

    # @return [Puppet::Parser::AST] the expression that when evaluated produces a string that is the result of the heredoc
    attr_accessor :expr

    def initialize(hash)
      super
      # Laziliy initialize puppet pops when heredoc is used
      require 'puppet/pops'
    end

    def evaluate(scope)
      result = expr.evaluate(scope)
      validate(scope, result)
      result
    end

    def validate(scope, result)
      # ignore 'unspecified syntax'
      return unless syntax || syntax == ''
      func_name = nil # "check_#{syntax}_syntax"

      function_names_for_syntax(syntax()).each do |name|
        break if func_name = Puppet::Parser::Functions.function(name)
      end
      return unless func_name

      acceptor = Puppet::Pops::Validation::Acceptor.new()
      # Call validator and give it the location information from the expression (as opposed to where the heredoc
      # tag is).
      scope.send(func_name, [result, syntax(), acceptor, {:file=> expr.file(), :line => expr.line(), :pos => expr.pos()}])

      # This logic is a variation on error output also found in e_parser_adapter.rb. Can possibly be refactored
      # into common utility.
      warnings = acceptor.warnings
      errors = acceptor.errors

      return if warnings.size == 0 && errors.size == 0

      max_errors = Puppet[:max_errors]
      max_warnings = Puppet[:max_warnings] + 1
      max_deprecations = Puppet[:max_deprecations] + 1

      # If there are warnings output them
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

      # If there were errors, report all up to cap. Use Puppet formatter
      if errors.size > 0
        formatter = Puppet::Pops::Validation::DiagnosticFormatterPuppetStyle.new
        emitted = 0
        errors.each do |e|
          Puppet.err(formatter.format(e))
          emitted += 1
          break if emitted >= max_errors
        end
        warnings_message = warnings.size > 0 ? ", and #{warnings.size} warnings" : ""
        giving_up_message = "Found #{errors.size} errors#{warnings_message} when validating '#{syntax()}' heredoc text. Giving up"
        # Locate the exception where the heredoc is (detailed messages have reference to positions in the text).
        exception = Puppet::ParseError.new(giving_up_message, file(), line(), pos())
        raise exception
      end
    end

    def function_names_for_syntax(syntax)
      syntax = syntax.gsub(/\./, "_")
      segments = syntax.split(/\+/)
      result = []
      begin
        result << "check_#{segments.join("__")}_syntax"
        segments.shift
      end until segments.empty?
      result
    end
  end
end
