require 'puppet/face'
Puppet::Face.define(:plugin, '0.0.1') do
  summary "Interact with the Puppet plugin system"

  action :download do
    summary "Download plugins from the configured master"

    when_invoked do |options|
      require 'puppet/configurer/downloader'
      Puppet::Configurer::Downloader.new("plugin",
                                         Puppet[:plugindest],
                                         Puppet[:pluginsource],
                                         Puppet[:pluginsignore]).evaluate
    end
  end
end
