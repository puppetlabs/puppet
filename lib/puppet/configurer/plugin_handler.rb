# Break out the code related to plugins.  This module is
# just included into the agent, but having it here makes it
# easier to test.
require 'puppet/configurer'

class Puppet::Configurer::PluginHandler
  def initialize(factory)
    @factory = factory
  end

  # Retrieve facts from the central server.
  def download_plugins(environment)
    plugin_downloader = @factory.create_plugin_downloader(environment)

    result = []

    if Puppet.features.external_facts?
      plugin_fact_downloader = @factory.create_plugin_facts_downloader(environment)
      result += plugin_fact_downloader.evaluate
    end

    result += plugin_downloader.evaluate
    Puppet::Util::Autoload.reload_changed

    result
  end
end
