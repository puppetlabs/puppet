require 'puppet/application/indirection_base'

class Puppet::Application::Facts < Puppet::Application::IndirectionBase
  # Allows `puppet facts` actions to be run against environments that
  # don't exist locally, such as using the `--environment` flag to make a REST
  # request to a specific environment on a master. There is no way to set this
  # behavior per-action, so it must be set for the face as a whole.
  environment_mode :not_required
end
