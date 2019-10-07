require 'puppet'
require 'puppet/util/warnings'

module Puppet::Util
  module Connection
    extend Puppet::Util::Warnings

    # The logic for server and port is kind of gross. In summary:
    # IF an endpoint-specific setting is requested AND that setting has been set by the user
    #    Use that setting.
    #         The defaults for these settings are the "normal" server/masterport settings, so
    #         when they are unset we instead want to "fall back" to the failover-selected
    #         host/port pair.
    # ELSE IF we have a failover-selected host/port
    #    Use what the failover logic came up with
    # ELSE IF the server_list setting is in use
    #    Use the first entry - failover hasn't happened yet, but that
    #    setting is still authoritative
    # ELSE
    #    Go for the legacy server/masterport settings, and hope for the best

    # Determines which server to use based on the specified setting, taking into
    # account HA fallback from server_list.
    # @param [Symbol] setting The preferred server setting to use
    # @return [String] the name of the server for use in the request
    def self.determine_server(setting)
      if setting && setting != :server && Puppet.settings.set_by_config?(setting)
        debug_once _("Selected server from the %{setting} setting: %{server}") % {setting: setting, server: Puppet.settings[setting]}
        Puppet[setting]
      else
        server = Puppet.lookup(:server) do
          primary_server = Puppet.settings[:server_list][0]
          if primary_server
            #TRANSLATORS 'server_list' is the name of a setting and should not be translated
            debug_once _("Dynamically-bound server lookup failed; using first entry from the `server_list` setting: %{server}") % {server: primary_server[0]}
            primary_server[0]
          else
            setting ||= :server
            debug_once _("Dynamically-bound server lookup failed, falling back to %{setting} setting: %{server}") % {setting: setting, server: Puppet.settings[setting]}
            Puppet.settings[setting]
          end
        end
        server
      end
    end

    # Determines which port to use based on the specified setting, taking into
    # account HA fallback from server_list.
    # For port there's a little bit of an extra snag: setting a specific
    # server setting and relying on the default port for that server is
    # common, so we also want to check if the assocaited SERVER setting
    # has been set by the user. If either of those are set we ignore the
    # failover-selected port.
    # @param [Symbol] port_setting The preferred port setting to use
    # @param [Symbol] server_setting The server setting assoicated with this route.
    # @return [Integer] the port to use for use in the request
    def self.determine_port(port_setting, server_setting)
      if (port_setting && port_setting != :masterport && Puppet.settings.set_by_config?(port_setting)) ||
         (server_setting && server_setting != :server && Puppet.settings.set_by_config?(server_setting))
        debug_once _("Selected port from the %{setting} setting: %{port}") % {setting: port_setting, port: Puppet.settings[port_setting].to_i}
        Puppet.settings[port_setting].to_i
      else
        port = Puppet.lookup(:serverport) do
          primary_server = Puppet.settings[:server_list][0]
          if primary_server
            # Port might not be set, so we want to fallback in that
            # case. We know we don't need to use `setting` here, since
            # the default value of every port setting is `masterport`
            if primary_server[1]
              #TRANSLATORS 'server_list' is the name of a setting and should not be translated
              debug_once _("Dynamically-bound port lookup failed; using first entry from the `server_list` setting: %{port}") % {port: primary_server[1]}
              primary_server[1]
            else
              #TRANSLATORS 'masterport' is the name of a setting and should not be translated
              debug_once _("Dynamically-bound port lookup failed; falling back to `masterport` setting: %{port}") % {port: Puppet.settings[:masterport]}
              Puppet.settings[:masterport]
            end
          else
            port_setting ||= :masterport
            debug_once _("Dynamically-bound port lookup failed; falling back to %{setting} setting: %{port}") % {setting: port_setting, port: Puppet.settings[port_setting]}
            Puppet.settings[port_setting]
          end
        end
        port.to_i
      end
    end
  end
end
