# Break out the code related to plugins.  This module is
# just included into the agent, but having it here makes it
# easier to test.
module Puppet::Configurer::PluginHandler
  # Retrieve facts from the central server.
  def download_plugins
    plugin_downloader = Puppet::Configurer::Downloader.new(
      "plugin",
      Puppet[:plugindest],
      Puppet[:pluginsource],
      Puppet[:pluginsignore],
      @environment
    )
    if Puppet.features.external_facts?
       plugin_fact_downloader = Puppet::Configurer::Downloader.new(
          "pluginfacts",
          Puppet[:pluginfactdest],
          Puppet[:pluginfactsource],
          Puppet[:pluginsignore],
          @environment
       )
       plugin_fact_downloader.evaluate
    end

    plugin_downloader.evaluate
    Puppet::Util::Autoload.reload_changed
  end
end
