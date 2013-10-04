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

    plugin_downloader.evaluate
    Puppet::Util::Autoload.reload_changed
  end
end
