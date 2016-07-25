require 'puppet/pops/parser/lexer2'

module Puppet
  module Generate
    module Util
      # Converts a Ruby string to a Puppet string literal.
      # @param string [String] The string to convert to a Puppet string literal.
      # @return [String] Returns the Puppet string literal (may not be quoted if the input is a bare word).
      def self.to_puppet_string(string)
        return string if !Puppet::Pops::Parser::Lexer2::KEYWORDS.keys.include?(string) &&
                         string =~ Puppet::Pops::Parser::Lexer2::PATTERN_BARE_WORD
        quoted = string.inspect
        return "'#{string}'" if !string.include?('\'') && "\"#{string}\"" == quoted
        quotede
      end
    end
  end
end
