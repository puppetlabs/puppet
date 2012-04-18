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
    is_upstart? ? [command(:start), @resource[:name]] : super
  end

  def stopcmd
    is_upstart? ? [command(:stop),  @resource[:name]] : super
  end

  def restartcmd
    is_upstart? ? (@resource[:hasrestart] == :true) && [command(:restart), @resource[:name]] : super
  end

  def statuscmd
    is_upstart? ? nil : super #this is because upstart is broken with its return codes
  end
  
  def status
    if @resource[:status]
      is_upstart?(@resource[:status]) ? upstart_status(@resource[:status]) : normal_status
    elsif is_upstart?
      upstart_status
    else
      super
    end
  end
  
  def normal_status
    ucommand(:status, false)
    ($?.exitstatus == 0) ? :running : :stopped
  end
  
  def upstart_status(exec = @resource[:name])
    output = status_exec(@resource[:name].split)
    if (! $?.nil?) && (output =~ /start\//)
      return :running
    else
      return :stopped
    end
  end
  
  def is_upstart?(script = initscript)
    File.symlink?(script) && File.readlink(script) == "/lib/init/upstart-job"
  end

end
