# The standard init-based service type.  Many other service types are
# customizations of this module.
Puppet::Type.type(:service).provide :init, :parent => :base do
  desc "Standard `init`-style service management."

  class << self
    attr_accessor :defpath
  end

  case Facter["operatingsystem"].value
  when "FreeBSD"
    @defpath = ["/etc/rc.d", "/usr/local/etc/rc.d"]
  when "HP-UX"
    @defpath = "/sbin/init.d"
  when "Archlinux"
    @defpath = "/etc/rc.d"
  else
    @defpath = "/etc/init.d"
  end

  # We can't confine this here, because the init path can be overridden.
  #confine :exists => @defpath

  # List all services of this type.
  def self.instances
    get_services(self.defpath)
  end

  def self.get_services(defpath, exclude=[])
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
        if File.exist?(path) and ! File.directory?(path)
          self.debug "Search path #{path} is not a directory"
        else
          self.debug "Search path #{path} does not exist"
        end
        false
      end
    end
  end

  def search(name)
    paths.each { |path|
      fqname = File.join(path,name)
      begin
        stat = File.stat(fqname)
      rescue
        # should probably rescue specific errors...
        self.debug("Could not find #{name} in #{path}")
        next
      end

      # if we've gotten this far, we found a valid script
      return fqname
    }

    paths.each { |path|
      fqname_sh = File.join(path,"#{name}.sh")
      begin
        stat = File.stat(fqname_sh)
      rescue
        # should probably rescue specific errors...
        self.debug("Could not find #{name}.sh in #{path}")
        next
      end

      # if we've gotten this far, we found a valid script
      return fqname_sh
    }
    raise Puppet::Error, "Could not find init script for '#{name}'"
  end

  # The start command is just the init scriptwith 'start'.
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

  # If it was specified that the init script has a 'status' command, then
  # we just return that; otherwise, we return false, which causes it to
  # fallback to other mechanisms.
  def statuscmd
    (@resource[:hasstatus] == :true) && [initscript, :status]
  end

end

