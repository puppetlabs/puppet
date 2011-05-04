require 'puppet/face'
Puppet::Face.define(:plugin, '0.0.1') do
  copyright "Puppet Labs", 2011
  license   "Apache 2 license; see COPYING"

  summary "Interact with the Puppet plugin system"

  action :download do
    summary "Download plugins from the configured master"
    returns <<-EOT
            An array containing the files actually downloaded.
            This will be empty array when everything was in sync.
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
