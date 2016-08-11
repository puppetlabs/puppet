# Manage debian services.  Start/stop is the same as InitSvc, but enable/disable
# is special.
Puppet::Type.type(:service).provide :debian, :parent => :init do
  desc <<-EOT
    Debian's form of `init`-style management.

    The only differences from `init` are support for enabling and disabling
    services via `update-rc.d` and the ability to determine enabled status via
    `invoke-rc.d`.

  EOT

  commands :update_rc => "/usr/sbin/update-rc.d"
  # note this isn't being used as a command until
  # https://projects.puppetlabs.com/issues/2538
  # is resolved.
  commands :invoke_rc => "/usr/sbin/invoke-rc.d"
  commands :service => "/usr/sbin/service"

  defaultfor :operatingsystem => :cumuluslinux, :operatingsystemmajrelease => ['1','2']
  defaultfor :operatingsystem => :debian, :operatingsystemmajrelease => ['5','6','7']

  # Remove the symlinks
  def disable
    if `dpkg --compare-versions $(dpkg-query -W --showformat '${Version}' sysv-rc) ge 2.88 ; echo $?`.to_i == 0
      update_rc @resource[:name], "disable"
    else
      update_rc "-f", @resource[:name], "remove"
      update_rc @resource[:name], "stop", "00", "1", "2", "3", "4", "5", "6", "."
    end
  end

  def enabled?
    # TODO: Replace system call when Puppet::Util::Execution.execute gives us a way
    # to determine exit status.  https://projects.puppetlabs.com/issues/2538
    system("/usr/sbin/invoke-rc.d", "--quiet", "--query", @resource[:name], "start")

    # 104 is the exit status when you query start an enabled service.
    # 106 is the exit status when the policy layer supplies a fallback action
    # See x-man-page://invoke-rc.d
    if [104, 106].include?($CHILD_STATUS.exitstatus)
      return :true
    elsif [101, 105].include?($CHILD_STATUS.exitstatus)
      # 101 is action not allowed, which means we have to do the check manually.
      # 105 is unknown, which generally means the initscript does not support query
      # The debian policy states that the initscript should support methods of query
      # For those that do not, perform the checks manually
      # http://www.debian.org/doc/debian-policy/ch-opersys.html
      if get_start_link_count >= 4
        return :true
      else
        return :false
      end
    else
      return :false
    end
  end

  def get_start_link_count
    Dir.glob("/etc/rc*.d/S??#{@resource[:name]}").length
  end

  def enable
    update_rc "-f", @resource[:name], "remove"
    update_rc @resource[:name], "defaults"
  end

  def statuscmd
      # /usr/sbin/service provides an abstraction layer which is able to query services
      # independent of the init system used.
      # See https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=775795
    (@resource[:hasstatus] == :true) && [command(:service), @resource[:name], "status"]
  end
end
