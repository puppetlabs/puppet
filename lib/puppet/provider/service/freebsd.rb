Puppet::Type.type(:service).provide :freebsd2, :parent => :init do

  desc "Provider for FreeBSD. Makes use of rcvar argument of init scripts and parses/edits rc files."

  confine :operatingsystem => [:freebsd]

  @@rcconf = '/etc/rc.conf'
  @@rcconf_local = '/etc/rc.conf.local'
  @@rcconf_dir = '/etc/rc.conf.d'

  def self.defpath
    superclass.defpath
  end

  # Executing an init script with the 'rcvar' argument returns
  # the service name and whether it's enabled/disabled
  def rcvar
    rcvar = execute([self.initscript, :rcvar], :failonfail => true, :squelch => false)
    rcvar = rcvar.lines.to_a[1].gsub(/\n/, "")
    self.debug("rcvar is #{rcvar}")
    return rcvar
  end

  # Extract the service name from the rcvar
  def rcvar_name
    name = self.rcvar.gsub(/(.*)_enable=(.*)/, '\1')
    self.debug("rcvar name is #{name}")
    return name
  end

  # Edit rc files and set the service to yes/no
  def rc_edit(yesno)
    name = self.rcvar_name
    self.debug("Editing rc files: setting #{name} to #{yesno}")
    if not self.rc_replace(yesno, name)
      self.rc_add(yesno, name)
    end
  end

  # Try to find an existing setting in the rc files 
  # and replace the value
  def rc_replace(yesno, name)
    success = false
    # Replace in all files, not just in the first found with a match
    [@@rcconf, @@rcconf_local, @@rcconf_dir + "/#{name}"].each do |filename|
      if File.exists?(filename)
        s = File.read(filename)
        if s.gsub!(/(#{name}_enable)=\"?(YES|NO)\"?/, "\\1=\"#{yesno}\"")
          File.open(filename, File::WRONLY) { |f| f << s }
          self.debug("Replaced in #{filename}")
          success = true
        end
      end
    end
    return success
  end

  # Add a new setting to the rc files
  def rc_add(yesno, name)
    append = "\n\# Added by Puppet\n#{name}_enable=\"#{yesno}\""
    # First, try the one-file-per-service style
    if File.exists?(@@rcconf_dir)
      File.open(@@rcconf_dir + "/#{name}", File::WRONLY | File::APPEND | File::CREAT, 0644) {
        |f| f << append
        self.debug("Appended to #{f.path}")
      }
    else
      # Else, check the local rc file first, but don't create it
      if File.exists?(@@rcconf_local)
        File.open(@@rcconf_local, File::WRONLY | File::APPEND) {
          |f| f << append
          self.debug("Appended to #{f.path}")
        }
      else
        # At last use the standard rc.conf file
        File.open(@@rcconf, File::WRONLY | File::APPEND | File::CREAT, 0644) {
          |f| f << append
          self.debug("Appended to #{f.path}")
        }
      end
    end
  end

  def enabled?
    if /YES$/ =~ self.rcvar then
      self.debug("Is enabled")
      return :true
    end
    self.debug("Is disabled")
    return :false
  end

  def enable
    self.debug("Enabling")
    self.rc_edit("YES")
  end

  def disable
    self.debug("Disabling")
    self.rc_edit("NO")
  end

  def startcmd
    [self.initscript, :onestart]
  end

  def stopcmd
    [self.initscript, :onestop]
  end

end
