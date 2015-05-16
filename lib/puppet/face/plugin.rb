require 'puppet/face'
require 'puppet/configurer/downloader_factory'
require 'puppet/configurer/plugin_handler'

Puppet::Face.define(:plugin, '0.0.1') do
  copyright "Puppet Labs", 2011
  license   "Apache 2 license; see COPYING"

  summary "Interact with the Puppet plugin system."
  description <<-'EOT'
    This subcommand provides network access to the puppet master's store of
    plugins.

    The puppet master serves Ruby code collected from the `lib` directories
    of its modules. These plugins can be used on agent nodes to extend
    Facter and implement custom types and providers. Plugins are normally
    downloaded by puppet agent during the course of a run.
  EOT

  action :download do
    summary "Download plugins from the puppet master."
    description <<-'EOT'
      Downloads plugins from the configured puppet master. Any plugins
      downloaded in this way will be used in all subsequent Puppet activity.
      This action modifies files on disk.
    EOT
    returns <<-'EOT'
      A list of the files downloaded, or a confirmation that no files were
      downloaded. When used from the Ruby API, this action returns an array of
      the files downloaded, which will be empty if none were retrieved.
    EOT
    examples <<-'EOT'
      Retrieve plugins from the puppet master:

      $ puppet plugin download

      Retrieve plugins from the puppet master (API example):

      $ Puppet::Face[:plugin, '0.0.1'].download
    EOT

    when_invoked do |options|
      remote_environment_for_plugins = Puppet::Node::Environment.remote(Puppet[:environment])

      factory = Puppet::Configurer::DownloaderFactory.new
      handler = Puppet::Configurer::PluginHandler.new(factory)
      handler.download_plugins(remote_environment_for_plugins)
    end

    when_rendering :console do |value|
      if value.empty? then
        "No plugins downloaded."
      else
        "Downloaded these plugins: #{value.join(', ')}"
      end
    end
  end
end
