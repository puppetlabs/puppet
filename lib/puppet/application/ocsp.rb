require 'puppet/application/indirection_base'

class Puppet::Application::Ocsp < Puppet::Application::IndirectionBase
  run_mode :agent
end
