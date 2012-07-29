# encoding: UTF-8

Puppet::Face.define(:module, '1.0.0') do
  action(:upgrade) do
    summary "Upgrade a puppet module."
    description <<-EOT
      Upgrades a puppet module.
    EOT

    returns "Hash"

    examples <<-EOT
      upgrade an installed module to the latest version

      $ puppet module upgrade puppetlabs-apache
      /etc/puppet/modules
      └── puppetlabs-apache (v1.0.0 -> v2.4.0)

      upgrade an installed module to a specific version

      $ puppet module upgrade puppetlabs-apache --version 2.1.0
      /etc/puppet/modules
      └── puppetlabs-apache (v1.0.0 -> v2.1.0)

      upgrade an installed module for a specific environment

      $ puppet module upgrade puppetlabs-apache --environment test
      /usr/share/puppet/environments/test/modules
      └── puppetlabs-apache (v1.0.0 -> v2.4.0)
    EOT

    arguments "<name>"

    option "--force", "-f" do
      summary "Force upgrade of an installed module."
      description <<-EOT
        Force the upgrade of an installed module even if there are local
        changes or the possibility of causing broken dependencies.
      EOT
    end

    option "--ignore-dependencies" do
      summary "Do not attempt to install dependencies."
      description <<-EOT
        Do not attempt to install dependencies
      EOT
    end

    option "--version=" do
      summary "The version of the module to upgrade to."
      description <<-EOT
        The version of the module to upgrade to.
      EOT
    end

    when_invoked do |name, options|
      name = name.gsub('/', '-')
      Puppet.notice "Preparing to upgrade '#{name}' ..."
      Puppet::ModuleTool.set_option_defaults options
      Puppet::ModuleTool::Applications::Upgrader.new(name, Puppet::Forge.new("PMT", self.version), options).run
    end

    when_rendering :console do |return_value|
      if return_value[:result] == :failure
        Puppet.err(return_value[:error][:multiline])
        exit 1
      elsif return_value[:result] == :noop
        Puppet.err(return_value[:error][:multiline])
        exit 0
      else
        tree = Puppet::ModuleTool.build_tree(return_value[:affected_modules], return_value[:base_dir])
        return_value[:base_dir] + "\n" +
        Puppet::ModuleTool.format_tree(tree)
      end
    end
  end
end
