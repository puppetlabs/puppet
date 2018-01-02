# A syntax checker for Base64.
# @api public
require 'puppet/syntax_checkers'
require 'base64'
class Puppet::SyntaxCheckers::Base64 < Puppet::Plugins::SyntaxCheckers::SyntaxChecker

  # Checks the text for BASE64 syntax issues and reports them to the given acceptor.
  # This checker allows the most relaxed form of Base64, including newlines and missing padding.
  # It also accept URLsafe input.
  #
  # @param text [String] The text to check
  # @param syntax [String] The syntax identifier in mime style (e.g. 'base64', 'text/xxx+base64')
  # @param acceptor [#accept] A Diagnostic acceptor
  # @param source_pos [Puppet::Pops::Adapters::SourcePosAdapter] A source pos adapter with location information
  # @api public
  #
  def check(text, syntax, acceptor, source_pos)
    raise ArgumentError.new(_("Base64 syntax checker: the text to check must be a String.")) unless text.is_a?(String)
    raise ArgumentError.new(_("Base64 syntax checker: the syntax identifier must be a String, e.g. json, data+json")) unless syntax.is_a?(String)
    raise ArgumentError.new(_("Base64 syntax checker: invalid Acceptor, got: '%{klass}'.") % { klass: acceptor.class.name }) unless acceptor.is_a?(Puppet::Pops::Validation::Acceptor)
    cleaned_text = text.gsub(/[\r?\n[:blank:]]/, '')
    begin
      # Do a strict decode64 on text with all whitespace stripped since the non strict version
      # simply skips all non base64 characters
      Base64.strict_decode64(cleaned_text)
    rescue
      msg = if (cleaned_text.bytes.to_a.size * 8) % 6 != 0
              _("Base64 syntax checker: Cannot parse invalid Base64 string - padding is not correct")
            else
              _("Base64 syntax checker: Cannot parse invalid Base64 string - contains letters outside strict base 64 range (or whitespace)")
            end

      # TODO: improve the pops API to allow simpler diagnostic creation while still maintaining capabilities
      # and the issue code. (In this case especially, where there is only a single error message being issued).
      #
      issue = Puppet::Pops::Issues::issue(:ILLEGAL_BASE64) { msg }
      acceptor.accept(Puppet::Pops::Validation::Diagnostic.new(:error, issue, source_pos.file, source_pos, {}))
    end
  end
end
