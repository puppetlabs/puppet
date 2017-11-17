# Break out the code related to plugins.  This module is
# just included into the agent, but having it here makes it
# easier to test.
require 'puppet/configurer'

class Puppet::Configurer::PluginHandler
  # Retrieve facts from the central server.
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
    locales_downloader = Puppet::Configurer::Downloader.new(
      "locales",
      Puppet[:localedest],
      Puppet[:localesource],
      Puppet[:localeignore],
      environment
    )

    result = []
    result += plugin_fact_downloader.evaluate
    result += plugin_downloader.evaluate
    result += locales_downloader.evaluate

    Puppet::Util::Autoload.reload_changed

    result
  end
end
