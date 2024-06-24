# frozen_string_literal: true

Puppet::Type.type(:package).provide :puppet_gem, :parent => :gem do
  desc "Puppet Ruby Gem support. This provider is useful for managing
        gems needed by the ruby provided in the puppet-agent package."

  has_feature :versionable, :install_options, :uninstall_options

  confine :true => Puppet.runtime[:facter].value(:aio_agent_version)

  commands :gemcmd => Puppet.run_mode.gem_cmd

  def uninstall
    super
    Puppet.debug("Invalidating rubygems cache after uninstalling gem '#{resource[:name]}'")
    Puppet::Util::Autoload.gem_source.clear_paths
  end

  def self.execute_gem_command(command, command_options, custom_environment = {})
    if (pkg_config_path = Puppet.run_mode.pkg_config_path)
      custom_environment['PKG_CONFIG_PATH'] = pkg_config_path
    end
    super(command, command_options, custom_environment)
  end
end
