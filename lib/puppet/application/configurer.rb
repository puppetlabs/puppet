require 'puppet/application'
require 'puppet/interface'

class Puppet::Application::Configurer < Puppet::Application
  should_parse_config
  run_mode :agent

  option("--debug","-d")
  option("--verbose","-v")

  def setup
    if options[:debug] or options[:verbose]
      Puppet::Util::Log.level = options[:debug] ? :debug : :info
    end

    Puppet::Util::Log.newdestination(:console)
  end

  def run_command
    report = Puppet::Interface::Configurer.synchronize(Puppet[:certname])
    Puppet::Interface::Report.submit(report)
  end
end
