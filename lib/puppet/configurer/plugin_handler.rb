# Break out the code related to plugins.  This module is
# just included into the agent, but having it here makes it
# easier to test.
require 'puppet/configurer'

class Puppet::Configurer::PluginHandler
  SUPPORTED_LOCALES_MOUNT_AGENT_VERSION = Gem::Version.new("5.3.4")

  def download_plugins(environment)
    source_permissions = Puppet.features.microsoft_windows? ? :ignore : :use

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

    server_agent_version = Puppet.lookup(:server_agent_version) { "0.0" }
    if Gem::Version.new(server_agent_version) >= SUPPORTED_LOCALES_MOUNT_AGENT_VERSION
      locales_downloader = Puppet::Configurer::Downloader.new(
        "locales",
        Puppet[:localedest],
        Puppet[:localesource],
        Puppet[:pluginsignore] + " *.pot config.yaml",
        environment
      )
      result += locales_downloader.evaluate
    end


    Puppet::Util::Autoload.reload_changed

    result
  end
end
