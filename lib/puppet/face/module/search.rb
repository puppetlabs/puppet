Puppet::Face.define(:module, '1.0.0') do
  action(:search) do
    summary "Search a repository for a module."
    description <<-EOT
      Search a repository for modules whose names match a specific substring.
    EOT

    returns "Array of module metadata hashes"

    examples <<-EOT
      Search the default repository for a module:

      $ puppet module search puppetlabs
      notice: Searching http://forge.puppetlabs.com
      notice: 24 found.
      puppetlabs/apache (0.0.3)
      puppetlabs/collectd (0.0.1)
      puppetlabs/ruby (0.0.1)
      puppetlabs/vcsrepo (0.0.4)
      puppetlabs/gcc (0.0.3)
      puppetlabs/passenger (0.0.2)
      puppetlabs/DeveloperBootstrap (0.0.5)
      jeffmccune/tomcat (1.0.1)
      puppetlabs/motd (1.0.0)
      puppetlabs/lvm (0.1.0)
      puppetlabs/rabbitmq (1.0.4)
      puppetlabs/prosvc_repo (1.0.1)
      puppetlabs/stdlib (2.2.0)
      puppetlabs/java (0.1.5)
      puppetlabs/activemq (0.1.6)
      puppetlabs/mcollective (0.1.8)
      puppetlabs/git (0.0.2)
      puppetlabs/ntp (0.0.4)
      puppetlabs/nginx (0.0.1)
      puppetlabs/cloud_provisioner (0.6.0rc1)
      puppetlabs/mrepo (0.1.1)
      puppetlabs/f5 (0.1.0)
      puppetlabs/firewall (0.0.3)
      puppetlabs/bprobe (0.0.3)
    EOT

    arguments "<term>"

    option "--module-repository=", "-r=" do
      default_to { Puppet.settings[:module_repository] }
      summary "Module repository to use."
      description <<-EOT
        Module repository to use.
      EOT
    end

    when_invoked do |term, options|
      Puppet.notice "Searching #{options[:module_repository]}"
      Puppet::Module::Tool::Applications::Searcher.run(term, options)
    end

    when_rendering :console do |return_value|
      Puppet.notice "#{return_value.size} found."
      return_value.map do |match|
        # We reference the full_name here when referring to the full_module_name,
        # because full_name is what is returned from the forge API call.
        "#{match['full_name']} (#{match['version']})"
      end.join("\n")
    end
  end
end
