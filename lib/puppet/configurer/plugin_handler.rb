# Break out the code related to plugins.  This module is
# just included into the agent, but having it here makes it
# easier to test.
require 'puppet/configurer'


class Puppet::Configurer::PluginHandler
  SUPPORTED_LOCALES_MOUNT_AGENT_VERSION = Gem::Version.new("5.3.4")

  def initialize(factory)
    @factory = factory
  end

  # Retrieve facts from the central server.
  def download_plugins(environment)
    plugin_downloader = @factory.create_plugin_downloader(environment)
    plugin_fact_downloader = @factory.create_plugin_facts_downloader(environment)
    result = []
    result += plugin_fact_downloader.evaluate
    result += plugin_downloader.evaluate

    server_agent_version = Puppet.lookup(:server_agent_version) { "0.0" }
    if Gem::Version.new(server_agent_version) >= SUPPORTED_LOCALES_MOUNT_AGENT_VERSION
      locales_downloader = @factory.create_locales_downloader(environment)
      result += locales_downloader.evaluate
    end

    Puppet::Util::Autoload.reload_changed

    result
  end
end
