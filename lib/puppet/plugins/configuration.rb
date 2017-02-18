# Configures the Puppet Plugins, by registering extension points
# and default implementations.
#
# See the respective configured services for more information.
#
# @api private
#
module Puppet::Plugins
  module Configuration
    require 'puppet/plugins/syntax_checkers'
    require 'puppet/syntax_checkers/base64'
    require 'puppet/syntax_checkers/json'

    def self.load_plugins
      # Register extensions
      # -------------------
      {
        SyntaxCheckers::SYNTAX_CHECKERS_KEY => {
          'json' => Puppet::SyntaxCheckers::Json.new,
          'base64' => Puppet::SyntaxCheckers::Base64.new
        }
      }
    end
  end
end
