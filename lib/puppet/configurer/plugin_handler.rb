# frozen_string_literal: true

# Break out the code related to plugins.  This module is
# just included into the agent, but having it here makes it
# easier to test.
require_relative '../../puppet/configurer'

class Puppet::Configurer::PluginHandler
  SUPPORTED_LOCALES_MOUNT_AGENT_VERSION = Gem::Version.new("5.3.4")

  def download_plugins(environment)
    source_permissions = Puppet::Util::Platform.windows? ? :ignore : :use

    plugin_downloader = Puppet::Configurer::Downloader.new(
      "plugin",
      Puppet[:plugindest],
      Puppet[:pluginsource],
      Puppet[:pluginsignore],
      environment
    )
    plugin_fact_downloader = Puppet::Configurer::Downloader.new(
      "pluginfacts",
      Puppet[:pluginfactdest],
      Puppet[:pluginfactsource],
      Puppet[:pluginsignore],
      environment,
      source_permissions
    )

    result = []
    result += plugin_fact_downloader.evaluate
    result += plugin_downloader.evaluate

    unless Puppet[:disable_i18n]
      # until file metadata/content are using the rest client, we need to check
      # both :server_agent_version and the session to see if the server supports
      # the "locales" mount
      server_agent_version = Puppet.lookup(:server_agent_version) { "0.0" }
      locales = Gem::Version.new(server_agent_version) >= SUPPORTED_LOCALES_MOUNT_AGENT_VERSION
      unless locales
        session = Puppet.lookup(:http_session)
        locales = session.supports?(:fileserver, 'locales') || session.supports?(:puppet, 'locales')
      end

      if locales
        locales_downloader = Puppet::Configurer::Downloader.new(
          "locales",
          Puppet[:localedest],
          Puppet[:localesource],
          Puppet[:pluginsignore] + " *.pot config.yaml",
          environment
        )
        result += locales_downloader.evaluate
      end
    end

    Puppet::Util::Autoload.reload_changed(Puppet.lookup(:current_environment))

    result
  end
end
