# A syntax checker for JSON.
# @api public
require 'puppet/syntax_checkers'
class Puppet::SyntaxCheckers::Json < Puppet::Plugins::SyntaxCheckers::SyntaxChecker

  # Checks the text for JSON syntax issues and reports them to the given acceptor.
  #
  # Error messages from the checker are capped at 100 chars from the source text.
  #
  # @param text [String] The text to check
  # @param syntax [String] The syntax identifier in mime style (e.g. 'json', 'json-patch+json', 'xml', 'myapp+xml'
  # @param acceptor [#accept] A Diagnostic acceptor
  # @param source_pos [Puppet::Pops::Adapters::SourcePosAdapter] A source pos adapter with location information
  # @api public
  #
  def check(text, syntax, acceptor, source_pos)
    raise ArgumentError.new(_("Json syntax checker: the text to check must be a String.")) unless text.is_a?(String)
    raise ArgumentError.new(_("Json syntax checker: the syntax identifier must be a String, e.g. json, data+json")) unless syntax.is_a?(String)
    raise ArgumentError.new(_("Json syntax checker: invalid Acceptor, got: '%{klass}'.") % { klass: acceptor.class.name }) unless acceptor.is_a?(Puppet::Pops::Validation::Acceptor)
    #raise ArgumentError.new("Json syntax checker: location_info must be a Hash") unless location_info.is_a?(Hash)

    begin
      Puppet::Util::Json.load(text)
    rescue => e
      # Cap the message to 100 chars and replace newlines
      msg = _("JSON syntax checker: Cannot parse invalid JSON string. \"%{message}\"") % { message: e.message().slice(0,100).gsub(/\r?\n/, "\\n") }

      # TODO: improve the pops API to allow simpler diagnostic creation while still maintaining capabilities
      # and the issue code. (In this case especially, where there is only a single error message being issued).
      #
      issue = Puppet::Pops::Issues::issue(:ILLEGAL_JSON) { msg }
      acceptor.accept(Puppet::Pops::Validation::Diagnostic.new(:error, issue, source_pos.file, source_pos, {}))
    end
  end
end
