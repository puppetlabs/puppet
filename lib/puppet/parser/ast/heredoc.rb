require 'puppet/parser/ast/branch'

class Puppet::Parser::AST
  # Evaluates its single text expression.
  # In addition to producing a string Heredoc also validates the produced string if
  # syntax has been set and there is an extension binding available for the given syntax.
  # If no checker is available validation is silently skipped. (TODO: Decide if this is ok
  # or needs a setting).
  #
  # Caveats
  # -------
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
      # Laziliy initialize puppet pops when heredoc is used (mainly for testing as Heredoc parsing requires future parser)
      require 'puppet/pops'
      require 'puppetx'
      tf = Puppet::Pops::Types::TypeFactory
      # Due to lazy initialization, HASH_OF_SYNTAX_CHECKERS is a class instance variable
      # TODO: can be simplified when Pops/Binder are no longer experimental
      @@HASH_OF_SYNTAX_CHECKERS ||= tf.hash_of(tf.type_of(::Puppetx::SYNTAX_CHECKERS_TYPE))
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

      checker = checker_for_syntax(scope, syntax())
      # ignore syntax with no matching checker
      return unless checker

      # Call checker and give it the location information from the expression
      # (as opposed to where the heredoc tag is (somewhere on the line above)).
      acceptor = Puppet::Pops::Validation::Acceptor.new()
      checker.check(result, syntax(), acceptor, {:file=> expr.file(), :line => expr.line(), :pos => expr.pos()})

      checker_message = "Invalid heredoc text having syntax: '#{syntax()}."
      Puppet::Pops::IssueReporter.assert_and_report(acceptor, :message => checker_message)
    end

    # Finds the most significant checker for the given syntax (most significant is to the right).
    # Returns nil if there is no registered checker.
    #
    def checker_for_syntax(scope, syntax)
      checkers_hash = scope.compiler.injector.lookup(scope, @@HASH_OF_SYNTAX_CHECKERS, ::Puppetx::SYNTAX_CHECKERS) || {}
      checkers_hash[lookup_keys_for_syntax(syntax).find {|x| checkers_hash[x] }]
    end

    # Returns an array of possible syntax names
    def lookup_keys_for_syntax(syntax)
      segments = syntax.split(/\+/)
      result = []
      begin
        result << segments.join("+")
        segments.shift
      end until segments.empty?
      result
    end
  end
end
