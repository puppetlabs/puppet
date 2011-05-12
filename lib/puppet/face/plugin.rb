require 'puppet/face'
Puppet::Face.define(:plugin, '0.0.1') do
  copyright "Puppet Labs", 2011
  license   "Apache 2 license; see COPYING"

  summary "Interact with the Puppet plugin system"
  description <<-EOT
    This face provides network access to the puppet master's store of
    plugins. It is intended for use in other faces, rather than for direct
    command line access.
  EOT
  notes <<-EOT
    The puppet master can serve Ruby code collected from the lib directories
    of its modules. These plugins can be used on agent nodes to extend
    Facter and implement custom types and providers.
  EOT

  action :download do
    summary "Download plugins from the configured master"
    returns <<-EOT
      An array containing the files actually downloaded. If all files
      were in sync, this array will be empty.
    EOT
    notes "This action modifies files on disk without returning any data."
    examples <<-EOT
      Retrieve plugins from the puppet master:

          Puppet::Face[:plugin, '0.0.1'].download
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
