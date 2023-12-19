# frozen_string_literal: true

# Configures the Puppet Plugins, by registering extension points
# and default implementations.
#
# See the respective configured services for more information.
#
# @api private
#
module Puppet::Plugins
  module Configuration
    require_relative '../../puppet/plugins/syntax_checkers'
    require_relative '../../puppet/syntax_checkers/base64'
    require_relative '../../puppet/syntax_checkers/json'
    require_relative '../../puppet/syntax_checkers/pp'
    require_relative '../../puppet/syntax_checkers/epp'

    def self.load_plugins
      # Register extensions
      # -------------------
      {
        SyntaxCheckers::SYNTAX_CHECKERS_KEY => {
          'json' => Puppet::SyntaxCheckers::Json.new,
          'base64' => Puppet::SyntaxCheckers::Base64.new,
          'pp' => Puppet::SyntaxCheckers::PP.new,
          'epp' => Puppet::SyntaxCheckers::EPP.new
        }
      }
    end
  end
end
