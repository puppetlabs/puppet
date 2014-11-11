# This module is an integral part of the evaluator. It deals with the concern of validating
# external syntax in text produced by heredoc and templates.
#
require 'puppet/plugins/syntax_checkers'
module Puppet::Pops::Evaluator::ExternalSyntaxSupport
  # TODO: This can be simplified if the Factory directly supported hash_of/type_of
  TYPES = Puppet::Pops::Types::TypeFactory
  SERVICE_TYPE = Puppet::Plugins::SyntaxCheckers::SYNTAX_CHECKERS_TYPE
  SERVICE_NAME = Puppet::Plugins::SyntaxCheckers::SYNTAX_CHECKERS_KEY

  def assert_external_syntax(scope, result, syntax, reference_expr)
    @@HASH_OF_SYNTAX_CHECKERS ||= TYPES.hash_of(TYPES.type_of(SERVICE_TYPE))
    # ignore 'unspecified syntax'
    return if syntax.nil? || syntax == ''

    checker = checker_for_syntax(scope, syntax)
    # ignore syntax with no matching checker
    return unless checker

    # Call checker and give it the location information from the expression
    # (as opposed to where the heredoc tag is (somewhere on the line above)).
    acceptor = Puppet::Pops::Validation::Acceptor.new()
    source_pos = find_closest_positioned(reference_expr)
    checker.check(result, syntax, acceptor, source_pos)

    if acceptor.error_count > 0
      checker_message = "Invalid produced text having syntax: '#{syntax}'."
      Puppet::Pops::IssueReporter.assert_and_report(acceptor, :message => checker_message)
      raise ArgumentError, "Internal Error: Configuration of runtime error handling wrong: should have raised exception"
    end
  end

  # Finds the most significant checker for the given syntax (most significant is to the right).
  # Returns nil if there is no registered checker.
  #
  def checker_for_syntax(scope, syntax)
    checkers_hash = scope.compiler.injector.lookup(scope, @@HASH_OF_SYNTAX_CHECKERS, SERVICE_NAME) || {}
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
