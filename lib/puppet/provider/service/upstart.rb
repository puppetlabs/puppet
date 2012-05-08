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
      if File.open(initscript).read.match(/^\s*start\s+on/)
        return :true
      else
        return :false
      end
    else
      super
    end
  end

  def enable
    if is_upstart?
      # Parens is needed to match parens in a multiline upstart start on stanza
      parens = 0

      script_text = File.open(initscript).read
      enabled_script =
        # Two cases, either there is a start on line already or we need to add one
        if script_text.to_s.match(/^\s*#*\s*start\s+on/)
          script_text.map do |line|
            if line.match(/^\s*#+\s*start\s+on/)
              # If there are more opening parens than closing parens, we need to uncomment a multiline 'start on' stanzas.
              if (line.count('(') > line.count(')') )
                parens = line.count('(') - line.count(')')
              end
              line.gsub(/^(\s*)#+(\s*start\s+on)/, '\1\2')
            elsif parens > 0
              # If there are still more opening than closing parens we need to continue uncommenting lines
              parens += (line.count('(') - line.count(')') )
              line.gsub(/^(\s*)#+/, '\1')
            else
              line
            end
          end
        else
          # If there is no "start on" it isn't enabled and needs that line added
          script_text.to_s + "\nstart on runlevel [2,3,4,5]"
        end

      Puppet::Util.replace_file(initscript, 0644) do |file|
        file.write(enabled_script)
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

      disabled_script = script_text.map do |line|
        if line.match(/^\s*start\s+on/)
          # If there are more opening parens than closing parens, we need to comment out a multiline 'start on' stanza
          if (line.count('(') > line.count(')') )
            parens = line.count('(') - line.count(')')
          end
          line.gsub(/^(\s*start\s+on)/, '#\1')
        elsif parens > 0
          # If there are still more opening than closing parens we need to continue uncommenting lines
          parens += (line.count('(') - line.count(')') )
          "#" << line
        else
          line
        end
      end

      Puppet::Util.replace_file(initscript, 0644) do |file|
        file.write(disabled_script)
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
