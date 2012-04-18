Puppet::Type.type(:service).provide :upstart, :parent => :debian do
  desc "Ubuntu service management with `upstart`.

  This provider manages `upstart` jobs, which have replaced `initd` services
  on Ubuntu. For `upstart` documentation, see <http://upstart.ubuntu.com/>.
  "
  # confine to :ubuntu for now because I haven't tested on other platforms
  confine :operatingsystem => :ubuntu #[:ubuntu, :fedora, :debian]
  
  defaultfor :operatingsystem => :ubuntu

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
      process.each_line { |line|
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
    if is_upstart?
      [command(:start), @resource[:name]]
    else
      super
    end
  end

  def stopcmd
    if is_upstart? then
      [command(:stop), @resource[:name]]
    else
      super
    end
  end

  def restartcmd
    if is_upstart? then
      (@resource[:hasrestart] == :true) && [command(:restart), @resource[:name]]
    else
      super
    end
  end
  
  def statuscmd
    if @resource[:hasstatus] == :true then 
      # Workaround the fact that initctl status command doesn't return
      # proper exit codes. Can be removed once LP: #552786 is fixed.
      if is_upstart? then
        ['sh', '-c', "LANG=C invoke-rc.d #{File::basename(initscript)} status | grep -q '^#{File::basename(initscript)}.*running'" ]
      else
        super
      end
    end
  end
  
  def is_upstart?
    File.symlink?(initscript) && File.readlink(initscript) == "/lib/init/upstart-job"
  end

end
