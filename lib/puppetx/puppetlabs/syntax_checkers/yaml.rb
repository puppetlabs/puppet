require 'puppetx/puppet/syntax_checker'

# A syntax checker for YAML.
# @api public
class Puppetx::Puppetlabs::SyntaxCheckers::Yaml < Puppetx::Puppet::SyntaxChecker

  # Checks the text for YAML syntax issues and reports them to the given acceptor.
  #
  # @param text [String] The text to check
  # @param syntax [String] The syntax identifier in mime style (e.g. 'yaml', 'myapp+yaml')
  # @option location_info [String] :file The filename where the string originates
  # @option location_info [Integer] :line The line number identifying the location where the string is being used/checked
  # @option location_info [Integer] :position The position on the line identifying the location where the string is being used/checked
  # @return [Void]
  # @api public
  #
  def check(text, syntax, acceptor, location_info={})
    raise ArgumentError.new("Yaml syntax checker: the text to check must be a String.") unless text.is_a?(String)
    raise ArgumentError.new("Yaml syntax checker: the syntax identifier must be a String, e.g. json, data+json") unless syntax.is_a?(String)
    raise ArgumentError.new("Yaml syntax checker: invalid Acceptor, got: '#{acceptor.class.name}'.") unless acceptor.is_a?(Puppet::Pops::Validation::Acceptor)
    raise ArgumentError.new("Yaml syntax checker: location_info must be a Hash") unless location_info.is_a?(Hash)

    begin
      YAML.parse(text)
    rescue ScriptError, StandardError => e
      # Cap the message to 100 chars and replace newlines
      msg = "Yaml syntax checker: Cannot parse invalid YAML string. \"#{e.message().slice(0,100).gsub(/\r?\n/, "\\n")}\""

      # TODO: improve the pops API to allow simpler diagnostic creation while still maintaining capabilities
      # and the issue code. (In this case especially, where there is only a single error message being issued).
      #
      issue = Puppet::Pops::Issues.issue(:ILLEGAL_YAML) { msg }
      source_pos = Puppet::Pops::Adapters::SourcePosAdapter.new()
      source_pos.line = location_info[:line]
      source_pos.pos = location_info[:pos]
      acceptor.accept(Puppet::Pops::Validation::Diagnostic.new(:error, issue, location_info[:file], source_pos, {}))
    end
  end
end
