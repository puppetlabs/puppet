# frozen_string_literal: true

# A syntax checker for JSON.
# @api public
require_relative '../../puppet/syntax_checkers'
class Puppet::SyntaxCheckers::PP < Puppet::Plugins::SyntaxCheckers::SyntaxChecker
  # Checks the text for Puppet Language syntax issues and reports them to the given acceptor.
  #
  # Error messages from the checker are capped at 100 chars from the source text.
  #
  # @param text [String] The text to check
  # @param syntax [String] The syntax identifier in mime style (only accepts 'pp')
  # @param acceptor [#accept] A Diagnostic acceptor
  # @param source_pos [Puppet::Pops::Adapters::SourcePosAdapter] A source pos adapter with location information
  # @api public
  #
  def check(text, syntax, acceptor, source_pos)
    raise ArgumentError, _("PP syntax checker: the text to check must be a String.") unless text.is_a?(String)
    raise ArgumentError, _("PP syntax checker: the syntax identifier must be a String, e.g. pp") unless syntax == 'pp'
    raise ArgumentError, _("PP syntax checker: invalid Acceptor, got: '%{klass}'.") % { klass: acceptor.class.name } unless acceptor.is_a?(Puppet::Pops::Validation::Acceptor)

    begin
      Puppet::Pops::Parser::EvaluatingParser.singleton.parse_string(text)
    rescue => e
      # Cap the message to 100 chars and replace newlines
      msg = _("PP syntax checker: \"%{message}\"") % { message: e.message().slice(0, 500).gsub(/\r?\n/, "\\n") }

      # TODO: improve the pops API to allow simpler diagnostic creation while still maintaining capabilities
      # and the issue code. (In this case especially, where there is only a single error message being issued).
      #
      issue = Puppet::Pops::Issues.issue(:ILLEGAL_PP) { msg }
      acceptor.accept(Puppet::Pops::Validation::Diagnostic.new(:error, issue, source_pos.file, source_pos, {}))
    end
  end
end
