Puppet::Type.type(:service).provide :openbsd, :parent => :init do

  desc "Provider for OpenBSD's rc.d daemon control scripts"

  confine :operatingsystem => :openbsd
  defaultfor :operatingsystem => :openbsd
  has_feature :flaggable

  def self.rcconf()        '/etc/rc.conf' end
  def self.rcconf_local()  '/etc/rc.conf.local' end

  def self.defpath
    ["/etc/rc.d"]
  end

  def startcmd
    [self.initscript, "-f", :start]
  end

  def restartcmd
    (@resource[:hasrestart] == :true) && [self.initscript, "-f", :restart]
  end

  def statuscmd
    [self.initscript, :check]
  end

  # Fetch the state of all service resources
  def self.prefetch(resources)
    services = instances
    resources.keys.each do |name|
      if provider = services.find { |svc| svc.name == name }
        resources[name].provider = provider
      end
    end
  end

  # Return the list of rc scripts
  # @api private
  def self.rclist
    unless @rclist
      Puppet.debug "Building list of rc scripts"
      @rclist = []
      defpath.each do |p|
        Dir.glob(p + '/*').each do |item|
          @rclist << item if File.executable?(item)
        end
      end
    end
    @rclist
  end

  # Return a hash where the keys are the rc script names as symbols with flags
  # as values
  # @api private
  def self.rcflags
    unless @flag_hash
      Puppet.debug "Retrieving flags for all discovered services"

      Puppet.debug "Reading the contents of the rc conf files"

      if File.exists?(rcconf_local())
        rcconf_local_contents = File.readlines(rcconf_local())
      else
        rcconf_local_contents = []
      end

      if File.exists?(rcconf())
        rcconf_contents = File.readlines(rcconf())
      else
        rcconf_contents = []
      end

      @flag_hash = {}
      rclist().each do |rcitem|

        rcname = rcitem.split('/').last

        if flagline = rcconf_local_contents.find {|l| l =~ /^#{rcname}_flags/ }
          flag = parse_rc_line(flagline)
          @flag_hash[rcname.to_sym] ||= flag
        end

        # For the defaults, if the flags are set to 'NO', we skip setting the
        # flag here, since it will already be disabled, and this makes the
        # output of `puppet resource service` a bit more correct.
        if flagline = rcconf_contents.find {|l| l =~ /^#{rcname}_flags/ }
          flag = parse_rc_line(flagline)
          unless flag == "NO"
            @flag_hash[rcname.to_sym] ||= flag
          end
        end
        @flag_hash[rcname.to_sym] ||= nil
      end
    end
    @flag_hash
  end

  # @api private
  def self.parse_rc_line(rc_line)
    rc_line.sub!(/\s*#(.*)$/,'')
    regex = /\w+_flags=(.*)/
    rc_line.match(regex)[1].gsub(/^"/,'').gsub(/"$/,'')
  end

  # Read the rc.conf* files and determine the value of the flags
  # @api private
  def self.get_flags(rcname)
    rcflags()
    @flag_hash[rcname.to_sym]
  end

  def self.instances
    instances = []
    defpath.each do |path|
      unless File.directory?(path)
        Puppet.debug "Service path #{path} does not exist"
        next
      end

      rclist().each do |d|
        instances << new(
          :name      => File.basename(d),
          :path      => path,
          :flags     => get_flags(File.basename(d)),
          :hasstatus => true
        )
      end
    end
    instances
  end

  # @api private
  def rcvar_name
    self.name + '_flags'
  end

  # @api private
  def read_rcconf_local_text()
    if File.exists?(self.class.rcconf_local())
      File.read(self.class.rcconf_local())
    else
      []
    end
  end

  # @api private
  def load_rcconf_local_array
    if File.exists?(self.class.rcconf_local())
      File.readlines(self.class.rcconf_local()).map {|l|
        l.chomp!
      }
    else
      []
    end
  end

  # @api private
  def write_rc_contents(file, text)
    Puppet::Util.replace_file(file, 0644) do |f|
      f.write(text)
    end
  end

  # @api private
  def set_content_flags(content,flags)
    unless content.is_a? Array
      debug "content must be an array at flags"
      return ""
    else
      content.reject! {|l| l.nil? }
    end

    if flags.nil? or flags.size == 0
      if in_base?
        append = resource[:name] + '_flags=""'
      end
    else
      append = resource[:name] + '_flags="' + flags + '"'
    end

    if content.find {|l| l =~ /#{resource[:name]}_flags/ }.nil?
      content << append
    else
      content.map {|l| l.gsub!(/^#{resource[:name]}_flags="(.*)?"(.*)?$/, append) }
    end
    content
  end

  # @api private
  def remove_content_flags(content)
    content.reject {|l| l =~ /#{resource[:name]}_flags/ }
  end

  # return an array of the currently enabled pkg_scripts
  # @api private
  def pkg_scripts
    current = load_rcconf_local_array()
    if scripts = current.find{|l| l =~ /^pkg_scripts/ }
      if match = scripts.match(/^pkg_scripts="(.*)?"(.*)?$/)
        match[1].split(' ')
      else
        []
      end
    else
      []
    end
  end

  # return the array with the current resource added
  # @api private
  def pkg_scripts_append
    [pkg_scripts(), resource[:name]].flatten.uniq
  end

  # return the array without the current resource
  # @api private
  def pkg_scripts_remove
    pkg_scripts().reject {|s| s == resource[:name] }
  end

  # Modify the content array to contain the requsted pkg_scripts line and retun
  # the resulting array
  # @api private
  def set_content_scripts(content,scripts)
    unless content.is_a? Array
      debug "content must be an array at scripts"
      return ""
    else
      content.reject! {|l| l.nil? }
    end

    scripts_line = 'pkg_scripts="' + scripts.join(' ') + '"'

    if content.find {|l| l =~ /^pkg_scripts/ }.nil?
      content << scripts_line
    else
      # Replace the found pkg_scripts line with our own
      content.each_with_index {|l,i|
        if l =~ /^pkg_scripts/
          content[i] = scripts_line
        end
      }
    end
    content
  end

  # Determine if the rc script is included in base
  # @api private
  def in_base?
    script = File.readlines(self.class.rcconf).find {|s| s =~ /^#{rcvar_name}/ }
    !script.nil?
  end

  # @api private
  def default_disabled?
    line = File.readlines(self.class.rcconf).find {|l| l =~ /#{rcvar_name}/ }
    self.class.parse_rc_line(line) == 'NO'
  end

  def enabled?
    if in_base?
      if (@property_hash[:flags].nil? or @property_hash[:flags] == 'NO')
        :false
      else
        :true
      end
    else
      if (pkg_scripts().include?(@property_hash[:name]))
        :true
      else
        :false
      end
    end
  end

  def enable
    self.debug("Enabling #{self.name}")
  end

  # We should also check for default state
  def disable
    self.debug("Disabling #{self.name}")
  end

  def flags
    @property_hash[:flags]
  end

  def flags=(value)
    @property_hash[:flags] = value
  end

  def flush
    debug "Flusing resource for #{self.name}"

    # Here we load the contents of the rc.conf.local file into the contents
    # variable, modify it if needed, and then compare that to the original.  If
    # they are different, we write it out.

    original = load_rcconf_local_array()
    content = original

    debug @property_hash.inspect

    if resource[:enable] == :true
      #set_flags(resource[:flags])
      content = set_content_flags(content, resource[:flags])

      # We need only add append the resource name to the pkg_scripts if the
      # package is not found in the base system.

      if not in_base?
        content = set_content_scripts(content,pkg_scripts_append())
      end
    elsif resource[:enable] == :false

      # By virtue of being excluded from the base system, all packages are
      # disabled by default and need not be set in the rc.conf.local at all.

      if not in_base?
        content = remove_content_flags(content)
        content = set_content_scripts(content,pkg_scripts_remove())
      else
        if default_disabled?
          content = remove_content_flags(content)
        else
          content = set_content_flags(content, "NO")
        end
      end
    end

    # Make sure to append a newline to the end of the file
    unless content[-1] == ""
      content << ""
    end
    output = content.join("\n")

    # Write the contents only if necessary, and only once
    write_rc_contents(self.class.rcconf_local(), output)
  end
end
