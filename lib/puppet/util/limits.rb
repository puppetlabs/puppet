require 'puppet/util'

module Puppet::Util::Limits
  # @api private
  def setpriority(priority)
    return unless priority

    Process.setpriority(0, Process.pid, priority)
  rescue Errno::EACCES, NotImplementedError
    Puppet.warning(_("Failed to set process priority to '%{priority}'") % { priority: priority })
  end
end
