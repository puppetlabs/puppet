Puppet::Face.define(:module, '1.0.0') do
	action(:update) do
		summary "Update a puppet module."
		description <<-EOT
			Update a puppet module
		EOT
		
		returns "Hash"
		
		examples <<-EOT
      Update an installed module to the latest version

      $ puppet module update puppetlabs-apache
      /etc/puppet/modules
      └── puppetlabs-apache (v1.0.0 -> v2.4.0)

      Update an installed module to a specific version

      $ puppet module update puppetlabs-apache --version 2.1.0
      /etc/puppet/modules
      └── puppetlabs-apache (v1.0.0 -> v2.1.0)

      Update an installed module for a specific environment

      $ puppet module update puppetlabs-apache --env test
      /usr/share/puppet/environments/test/modules
      └── puppetlabs-apache (v1.0.0 -> v2.4.0)
		EOT
		
		arguments "<name>"
		
		option "--force", "-f" do
			summary "Force upgrade of an installed module."
			description <<-EOT
				Force the update of an installed module even if there are local
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
				The version of the module to update.
			EOT
		end
		
	  when_invoked do |name, options|
		  Puppet::Module::Tool::Applications::Updater.run(name, options)
		end
		
	  when_rendering :console do |return_value|
	  end
	end
end
