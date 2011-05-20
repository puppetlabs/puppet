Puppet::Type.type(:service).provide :upstart, :parent => :init do
  desc "Ubuntu service manager upstart.

  This provider manages upstart jobs which have replaced initd.

  See:
   * http://upstart.ubuntu.com/
  "
  # confine to :ubuntu for now because I haven't tested on other platforms
  confine :operatingsystem => :ubuntu #[:ubuntu, :fedora, :debian]

  commands :start   => "/sbin/start",
           :stop    => "/sbin/stop",
           :restart => "/sbin/restart",
           :status_exec  => "/sbin/status",
           :initctl => "/sbin/initctl"

  # upstart developer haven't implemented initctl enable/disable yet:
  # http://www.linuxplanet.com/linuxplanet/tutorials/7033/2/
  # has_feature :enableable

  def self.instances
    instances = []
    execpipe("#{command(:initctl)} list") { |process|
      process.each { |line|
        # needs special handling of services such as network-interface:
        # initctl list:
        # network-interface (lo) start/running
        # network-interface (eth0) start/running
        # network-interface-security start/running
        name = \
          if matcher = line.match(/^(network-interface)\s\(([^\)]+)\)/)
            "#{matcher[1]} INTERFACE=#{matcher[2]}"
          else
            line.split.first
          end
        instances << new(:name => name)
      }
    }
    instances
  end

  def startcmd
    [command(:start), @resource[:name]]
  end

  def stopcmd
    [command(:stop), @resource[:name]]
  end

  def restartcmd
    (@resource[:hasrestart] == :true) && [command(:restart), @resource[:name]]
  end

  def status
    # allows user override of status command
    if @resource[:status]
      ucommand(:status, false)
      if $?.exitstatus == 0
        return :running
      else
        return :stopped
      end
    else
      output = status_exec(@resource[:name].split)
      if (! $?.nil?) && (output =~ /start\//)
        return :running
      else
        return :stopped
      end
    end
  end
end
