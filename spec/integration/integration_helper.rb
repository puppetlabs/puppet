require 'puppet'
Puppet.initialize_settings
Puppet::Util::Log.newdestination(:console) # So that logs go somewhere visible

# tools for applying a catalog to the local system
# WARNING: this WILL alter your system if you tell it to.
class Apply
  require 'puppet/application/apply'
  def manifest(manifest)
    args = ['apply', '-e', manifest]
    command_line = Puppet::Util::CommandLine.new('puppet', args)

    apply = Puppet::Application::Apply.new(command_line)
    apply.parse_options
    apply.run_command
  end
end
