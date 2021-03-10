# The standard init-based service type.  Many other service types are
# customizations of this module.
Puppet::Type.type(:service).provide :init, :parent => :base do
  desc "Standard `init`-style service management."

  def self.defpath
    case Facter.value(:operatingsystem)
    when "FreeBSD", "DragonFly"
      ["/etc/rc.d", "/usr/local/etc/rc.d"]
    when "HP-UX"
      "/sbin/init.d"
    when "Archlinux"
      "/etc/rc.d"
    when "AIX"
      "/etc/rc.d/init.d"
    else
      "/etc/init.d"
    end
  end

  # Debian and Ubuntu should use the Debian provider.
  # RedHat systems should use the RedHat provider.
  confine :true => begin
      os = Facter.value(:operatingsystem).downcase
      family = Facter.value(:osfamily).downcase
      !(os == 'debian' || os == 'ubuntu' || family == 'redhat')
  end

  # We can't confine this here, because the init path can be overridden.
  #confine :exists => defpath

  # some init scripts are not safe to execute, e.g. we do not want
  # to suddenly run /etc/init.d/reboot.sh status and reboot our system. The
  # exclude list could be platform agnostic but I assume an invalid init script
  # on system A will never be a valid init script on system B
  def self.excludes
    excludes = []
    # these exclude list was found with grep -L '\/sbin\/runscript' /etc/init.d/* on gentoo
    excludes += %w{functions.sh reboot.sh shutdown.sh}
    # this exclude list is all from /sbin/service (5.x), but I did not exclude kudzu
    excludes += %w{functions halt killall single linuxconf reboot boot}
    # 'wait-for-state' and 'portmap-wait' are excluded from instances here
    # because they take parameters that have unclear meaning. It looks like
    # 'wait-for-state' is a generic waiter mainly used internally for other
    # upstart services as a 'sleep until something happens'
    # (http://lists.debian.org/debian-devel/2012/02/msg01139.html), while
    # 'portmap-wait' is a specific instance of a waiter. There is an open
    # launchpad bug
    # (https://bugs.launchpad.net/ubuntu/+source/upstart/+bug/962047) that may
    # eventually explain how to use the wait-for-state service or perhaps why
    # it should remain excluded. When that bug is addressed this should be
    # reexamined.
    excludes += %w{wait-for-state portmap-wait}
    # these excludes were found with grep -r -L start /etc/init.d
    excludes += %w{rcS module-init-tools}
    # Prevent puppet failing on unsafe scripts from Yocto Linux
    if Facter.value(:osfamily) == "cisco-wrlinux"
      excludes += %w{banner.sh bootmisc.sh checkroot.sh devpts.sh dmesg.sh
                   hostname.sh mountall.sh mountnfs.sh populate-volatile.sh
                   rmnologin.sh save-rtc.sh sendsigs sysfs.sh umountfs
                   umountnfs.sh}
    end
    # Prevent puppet failing to get status of the new service introduced
    # by the fix for this (bug https://bugs.launchpad.net/ubuntu/+source/lightdm/+bug/982889)
    # due to puppet's inability to deal with upstart services with instances.
    excludes += %w{plymouth-ready}
    # Prevent puppet failing to get status of these services, which need parameters
    # passed in (see https://bugs.launchpad.net/ubuntu/+source/puppet/+bug/1276766).
    excludes += %w{idmapd-mounting startpar-bridge}
    # Prevent puppet failing to get status of these services, additional upstart
    # service with instances
    excludes += %w{cryptdisks-udev}
    excludes += %w{statd-mounting}
    excludes += %w{gssd-mounting}
    excludes
  end

  # List all services of this type.
  def self.instances
    get_services(self.defpath)
  end

  def self.get_services(defpath, exclude = self.excludes)
    defpath = [defpath] unless defpath.is_a? Array
    instances = []
    defpath.each do |path|
      unless FileTest.directory?(path)
        Puppet.debug "Service path #{path} does not exist"
        next
      end

      check = [:ensure]

      check << :enable if public_method_defined? :enabled?

      Dir.entries(path).each do |name|
        fullpath = File.join(path, name)
        next if name =~ /^\./
        next if exclude.include? name
        next if not FileTest.executable?(fullpath)
        next if not is_init?(fullpath)
        instances << new(:name => name, :path => path, :hasstatus => true)
      end
    end
    instances
  end

  # Mark that our init script supports 'status' commands.
  def hasstatus=(value)
    case value
    when true, "true"; @parameters[:hasstatus] = true
    when false, "false"; @parameters[:hasstatus] = false
    else
      raise Puppet::Error, "Invalid 'hasstatus' value #{value.inspect}"
    end
  end

  # Where is our init script?
  def initscript
    @initscript ||= self.search(@resource[:name])
  end

  def paths
    @paths ||= @resource[:path].find_all do |path|
      if File.directory?(path)
        true
      else
        if Puppet::FileSystem.exist?(path)
          self.debug "Search path #{path} is not a directory"
        else
          self.debug "Search path #{path} does not exist"
        end
        false
      end
    end
  end

  def search(name)
    paths.each do |path|
      fqname = File.join(path,name)
      if Puppet::FileSystem.exist? fqname
        return fqname
      else
        self.debug("Could not find #{name} in #{path}")
      end
    end

    paths.each do |path|
      fqname_sh = File.join(path,"#{name}.sh")
      if Puppet::FileSystem.exist? fqname_sh
        return fqname_sh
      else
        self.debug("Could not find #{name}.sh in #{path}")
      end
    end
    raise Puppet::Error, "Could not find init script for '#{name}'"
  end

  # The start command is just the init script with 'start'.
  def startcmd
    [initscript, :start]
  end

  # The stop command is just the init script with 'stop'.
  def stopcmd
    [initscript, :stop]
  end

  def restartcmd
    (@resource[:hasrestart] == :true) && [initscript, :restart]
  end

  def texecute(type, command, fof = true, squelch = false, combine = true)
    if type == :start && Facter.value(:osfamily) == "Solaris"
        command =  ["/usr/bin/ctrun -l child", command].flatten.join(" ")
    end
    super(type, command, fof, squelch, combine)
  end

  # If it was specified that the init script has a 'status' command, then
  # we just return that; otherwise, we return false, which causes it to
  # fallback to other mechanisms.
  def statuscmd
    (@resource[:hasstatus] == :true) && [initscript, :status]
  end

private

  def self.is_init?(script = initscript)
    file = Puppet::FileSystem.pathname(script)
    !Puppet::FileSystem.symlink?(file) || Puppet::FileSystem.readlink(file) != "/lib/init/upstart-job"
  end
end

