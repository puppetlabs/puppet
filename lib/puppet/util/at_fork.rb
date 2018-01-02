require 'puppet'

# A module for building AtFork handlers. These handlers are objects providing
# pre/post fork callbacks modeled after those registered by the `pthread_atfork`
# function.
# Currently there are two AtFork handler implementations:
# - a noop implementation used on all platforms except Solaris (and possibly
#   even there as a fallback)
# - a Solaris implementation which ensures the forked process runs in a different
#   contract than the parent process. This is necessary for agent runs started by
#   the puppet agent service to be able to restart that service without being
#   killed in the process as a consequence of running in the same contract as the
#   service.
module Puppet::Util::AtFork
  @handler_class = loop do
    if Facter.value(:operatingsystem) == 'Solaris'
      begin
        require 'puppet/util/at_fork/solaris'
        # using break to return a value from the loop block
        break Puppet::Util::AtFork::Solaris
      rescue LoadError => detail
        Puppet.log_exception(detail, _('Failed to load Solaris implementation of the Puppet::Util::AtFork handler. Child process contract management will be unavailable, which means that agent runs executed by the puppet agent service will be killed when they attempt to restart the service.'))
        # fall through to use the no-op implementation
      end
    end

    require 'puppet/util/at_fork/noop'
    # using break to return a value from the loop block
    break Puppet::Util::AtFork::Noop
  end

  def self.get_handler
    @handler_class.new
  end
end
