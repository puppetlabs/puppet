Puppet::Face.define(:module, '1.0.0') do
  action(:upgrade) do
    summary "upgrade a puppet module."
    description <<-EOT
      upgrade a puppet module
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

      $ puppet module upgrade puppetlabs-apache --env test
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
    
    option "--environment=NAME", "--env=NAME" do
      default_to { "production" }
      summary "The target environment to search for modules."
      description <<-EOT
        The target environment to search for modules.
      EOT
    end
    
    option "--version=" do
      summary "The version of the module to upgrade"
      description <<-EOT
        The version of the module to upgrade.
      EOT
    end
    
    when_invoked do |name, options|
      Puppet.settings[:module_repository] = ENV['PUPPET_FORGE'] if ENV['PUPPET_FORGE']

      name = name.gsub('/', '-')
      Puppet.notice "Preparing to upgrade '#{name}' ..."
      Puppet::Module::Tool::Applications::Upgrader.new(name, options).run
    end
    
    when_rendering :console do |return_value|
      if return_value[:result] == :failure
        Puppet.err(return_value[:error][:multiline])
        exit 1
      else
        tree = format_tree(return_value[:affected_modules])
        return_value[:base_dir] + "\n" +
        Puppet::Module::Tool.build_tree(tree)
      end
    end
  end
end

def format_tree(mods, indent = '')
  mods.each do |mod|
    version_string = mod[:version][:vstring].sub(/^(?!v)/, 'v')

    if mod[:action] == :upgrade
      previous_version = mod[:previous_version].sub(/^(?!v)/, 'v')
      version_string = "#{previous_version} -> #{version_string}"
    end

    mod[:text] = "#{mod[:module]} (#{version_string})"
    format_tree(mod[:dependencies])
  end
end
