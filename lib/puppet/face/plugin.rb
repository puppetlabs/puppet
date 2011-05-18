require 'puppet/face'
Puppet::Face.define(:plugin, '0.0.1') do
  copyright "Puppet Labs", 2011
  license   "Apache 2 license; see COPYING"

  summary "Interact with the Puppet plugin system."
  description <<-'EOT'
    This face provides network access to the puppet master's store of
    plugins.
  EOT
  notes <<-'EOT'
    The puppet master can serve Ruby code collected from the lib directories
    of its modules. These plugins can be used on agent nodes to extend
    Facter and implement custom types and providers.
  EOT

  action :download do
    summary "Download plugins from the puppet master."
    description <<-'EOT'
      Downloads plugins from the configured puppet master. Any plugins
      downloaded in this way will be used in all subsequent Puppet activity.
    EOT
    returns <<-'EOT'
      A display-formatted list of the files downloaded. If all plugin
      files were in sync, this list will be empty.
    EOT
    notes "This action modifies files on disk."
    examples <<-'EOT'
      Retrieve plugins from the puppet master:

      $ puppet plugin download

      Retrieve plugins from the puppet master (API example):

      $ Puppet::Face[:plugin, '0.0.1'].download
    EOT

    when_invoked do |options|
      require 'puppet/configurer/downloader'
      Puppet::Configurer::Downloader.new("plugin",
                                         Puppet[:plugindest],
                                         Puppet[:pluginsource],
                                         Puppet[:pluginsignore]).evaluate
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
