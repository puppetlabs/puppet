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
    plugin_fact_downloader = @factory.create_plugin_facts_downloader(environment)
    locales_downloader = @factory.create_locales_downloader(environment)
    result = []
    result += plugin_fact_downloader.evaluate
    result += plugin_downloader.evaluate
    result += locales_downloader.evaluate

    Puppet::Util::Autoload.reload_changed

    result
  end
end
