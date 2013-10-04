# Gentoo OpenRC
Puppet::Type.type(:service).provide :openrc, :parent => :base do
  desc <<-EOT
    Support for Gentoo's OpenRC initskripts

    Uses rc-update, rc-status and rc-service to manage services.

  EOT

  defaultfor :operatingsystem => :gentoo
  defaultfor :operatingsystem => :funtoo

  has_command(:rcstatus, '/bin/rc-status') do
    environment :RC_SVCNAME => nil
  end
  commands :rcservice => '/sbin/rc-service'
  commands :rcupdate  => '/sbin/rc-update'

  self::STATUSLINE = /^\s+(.*?)\s*\[\s*(.*)\s*\]$/

  def enable
    rcupdate('-C', :add, @resource[:name])
  end

  def disable
    rcupdate('-C', :del, @resource[:name])
  end

  # rc-status -a shows all runlevels and dynamic runlevels which
  # are not considered as enabled. We have to find out under which
  # runlevel our service is listed
  def enabled?
    enabled = :false
    rcstatus('-C', '-a').each_line do |line|
      case line.chomp
      when /^Runlevel: /
        enabled = :true
      when /^\S+/ # caption of a dynamic runlevel
        enabled = :false
      when self.class::STATUSLINE
        return enabled if @resource[:name] == $1
      end
    end
    :false
  end

  def self.instances
    instances = []
    rcservice('-C', '--list').each_line do |line|
      instances << new(:name => line.chomp)
    end
    instances
  end

  def restartcmd
    (@resource[:hasrestart] == :true) && [command(:rcservice), @resource[:name], :restart]
  end

  def startcmd
    [command(:rcservice), @resource[:name], :start ]
  end

  def stopcmd
    [command(:rcservice), @resource[:name], :stop]
  end

  def statuscmd
    ((@resource.provider.get(:hasstatus) == true) || (@resource[:hasstatus] == :true)) && [command(:rcservice), @resource[:name], :status]
  end

end
