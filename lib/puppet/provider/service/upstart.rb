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
  has_feature :enableable

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

  def self.defpath
    ["/etc/init.d", "/etc/init"]
  end

  def upstart_version
    @@upstart_version ||= Puppet::Util.execute(command(:initctl) + " --version", {true, true}).match(/initctl \(upstart (\d\.\d[\.\d]?)\)/)[1]
  end

  # Where is our override script?
  def overscript
    @overscript ||= initscript.gsub(/\.conf$/,".override")
  end

  def search(name)
    # Search prefers .conf as that is what upstart uses
    [".conf", "", ".sh"].each do |suffix|
      paths.each { |path|
        fqname = File.join(path,name+suffix)
        begin
          stat = File.stat(fqname)
        rescue
          # should probably rescue specific errors...
          self.debug("Could not find #{name}#{suffix} in #{path}")
          next
        end

        # if we've gotten this far, we found a valid script
        return fqname
      }
    end

    raise Puppet::Error, "Could not find init script or upstart conf file for '#{name}'"
  end

  def enabled?
    if is_upstart?
      if Puppet::Util::Package.versioncmp(upstart_version, "0.6.7") == -1
        # Upstart version < 0.6.7 means no manual stanza.
        if File.open(initscript).read.match(/^\s*start\s+on/)
          return :true
        else
          return :false
        end
      elsif upstart_version < "0.9.0"
        # Upstart version < 0.9.0 means no override files
        # So we check to see if an uncommented start on or manual stanza is the last one in the file
        # The last one in the file wins.
        enabled = :false
        File.open(initscript).read.each do |line|
          if line.match(/^\s*start\s+on/)
            enabled = :true
          elsif line.match(/^\s*manual\s*$/)
            enabled = :false
          end
        end
        enabled
      else
        # This version has manual stanzas and override files
        # So we check to see if an uncommented start on or manual stanza is the last one in the
        # conf file and any override files. The last one in the file wins.
        enabled = :false
        @conf_enabled = false
        script_text = File.open(initscript).read
        begin
          over_text = File.open(overscript).read
        rescue
          over_text = nil
        end

        script_text.each do |line|
          if line.match(/^\s*start\s+on/)
            enabled = :true
            @conf_enabled = true
          elsif line.match(/^\s*manual\s*$/)
            enabled = :false
            @conf_enabled = false
          end
        end
        over_text.each do |line|
          if line.match(/^\s*start\s+on/)
            enabled = :true
          elsif line.match(/^\s*manual\s*$/)
            enabled = :false
          end
        end if over_text
        enabled
      end
    else
      super
    end
  end

  def enable
    if is_upstart?
      script_text = File.open(initscript).read
      # Parens is needed to match parens in a multiline upstart start on stanza
      parens = 0
      if Puppet::Util::Package.versioncmp(upstart_version, "0.9.0") == -1
        enabled_script =
          # Two cases, either there is a start on line already or we need to add one
          if script_text.to_s.match(/^\s*#*\s*start\s+on/)
            script_text.map do |line|
              # t_line is used for paren counting and chops off any trailing comments before counting parens
              t_line = line.gsub(/^(\s*#+\s*[^#]*).*/, '\1')
              if line.match(/^\s*#+\s*start\s+on/)
                # If there are more opening parens than closing parens, we need to uncomment a multiline 'start on' stanzas.
                if (t_line.count('(') > t_line.count(')') )
                  parens = t_line.count('(') - t_line.count(')')
                end
                line.gsub(/^(\s*)#+(\s*start\s+on)/, '\1\2')
              elsif parens > 0
                # If there are still more opening than closing parens we need to continue uncommenting lines
                parens += (t_line.count('(') - t_line.count(')') )
                line.gsub(/^(\s*)#+/, '\1')
              else
                line
              end
            end
          else
            # If there is no "start on" it isn't enabled and needs that line added
            script_text.to_s + "\nstart on runlevel [2,3,4,5]"
          end

        unless Puppet::Util::Package.versioncmp(upstart_version, "0.6.7") == -1
          # We also need to remove any manual stanzas to ensure that it is enabled
          enabled_script.each do |line|
            line.gsub!(/^\s*manual\s*$/, "")
          end
        end

        Puppet::Util.replace_file(initscript, 0644) do |file|
          file.write(enabled_script)
        end

      else
        # We have override files in this case. So this breaks down to the following cases...
        # 1.) conf has 'start on' and no 'manual', override has 'manual' => remove 'manual' from override
        # 2.) conf has 'start on' and 'manual', override may or may not have 'manual' =>
        #                              remove 'manual' from override if present, copy 'start on' from conf to override
        # 3.) conf has no 'start on', override has 'manual' or no 'start on' => remove manual if present, add 'start on'
        # 4.) conf has no 'start on', override has 'manual' and has 'start on' => remove manual
        begin
          over_text = File.open(overscript).read
        rescue
          over_text = nil
        end

        if script_text.match(/^\s*start\s+on/) and not script_text.match(/^\s*manual\s*$/)
          # Case #1 from above - override has manual
          over_text.gsub!(/^\s*manual\s*$/,"") if over_text
        elsif script_text.match(/^\s*start\s+on/) and script_text.match(/^\s*manual\s*$/)
          # Case #2 from above
          # If the conf file was already enabled, all we need to do is remove the manual stanza from the override file
          if @conf_enabled
            # Remove any manual stanzas from the override file
            over_text.gsub!(/^\s*manual\s*$/,"") if over_text
          else
            # If the override has no start stanza, copy it from the conf file
            # First, copy the start on lines from the conf file
            start_on = script_text.map do |line|
              t_line = line.gsub(/^([^#]*).*/, '\1')

              if line.match(/^\s*start\s+on/)
                if (t_line.count('(') > t_line.count(')') )
                  parens = t_line.count('(') - t_line.count(')')
                end
                line
              elsif parens > 0
                parens += (t_line.count('(') - t_line.count(')') )
                line
              end
            end

            # Remove any manual stanzas from the override file
            over_text.gsub!(/^\s*manual\s*$/,"") if over_text

            # Add the copied 'start on' stanza if needed
            over_text << start_on.to_s if over_text and not over_text.match(/^\s*start\s+on/)
            over_text = start_on.to_s unless over_text
          end
        elsif not script_text.match(/^\s*start\s+on/)
          # Case #3 and #4 from above
          over_text.gsub!(/^\s*manual\s*$/,"") if over_text
          over_text << "\nstart on runlevel [2,3,4,5]" if over_text and not over_text.match(/^\s*start\s+on/)
          over_text = "\nstart on runlevel [2,3,4,5]" unless over_text
        end

        Puppet::Util.replace_file(overscript, 0644) do |file|
          file.write(over_text)
        end
      end
    else
      super
    end
  end

  def disable
    if is_upstart?
      # Parens is needed to match parens in a multiline upstart start on stanza
      parens = 0
      script_text = File.open(initscript).read

      if Puppet::Util::Package.versioncmp(upstart_version, "0.6.7") == -1
        disabled_script = script_text.map do |line|
          t_line = line.gsub(/^([^#]*).*/, '\1')
          if line.match(/^\s*start\s+on/)
            # If there are more opening parens than closing parens, we need to comment out a multiline 'start on' stanza
            if (t_line.count('(') > t_line.count(')') )
              parens = t_line.count('(') - t_line.count(')')
            end
            line.gsub(/^(\s*start\s+on)/, '#\1')
          elsif parens > 0
            # If there are still more opening than closing parens we need to continue uncommenting lines
            parens += (t_line.count('(') - t_line.count(')') )
            "#" << line
          else
            line
          end
        end

        Puppet::Util.replace_file(initscript, 0644) do |file|
          file.write(disabled_script)
        end
      elsif Puppet::Util::Package.versioncmp(upstart_version, "0.9.0") == -1
        disabled_script = script_text.gsub(/^\s*manual\s*$/,"")
        disabled_script << "\nmanual"

        Puppet::Util.replace_file(initscript, 0644) do |file|
          file.write(disabled_script)
        end
      else
        # We have override files in this case.
        # So we remove any existing manual stanzas and add one at the end
        begin
          over_text = File.open(overscript).read
        rescue
          over_text = nil
        end

        # First, remove any manual stanzas
        over_text.gsub!(/^\s*manual\s*$/,"") if over_text

        # Then add a manual stanza at the end.
        over_text << "\nmanual" if over_text
        over_text = "manual" unless over_text

        Puppet::Util.replace_file(overscript, 0644) do |file|
          file.write(over_text)
        end
      end
    else
      super
    end
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
    return true if (File.symlink?(script) && File.readlink(script) == "/lib/init/upstart-job")
    return true if (File.file?(script) && (not script.include?("init.d")))
    return false
  end

end
