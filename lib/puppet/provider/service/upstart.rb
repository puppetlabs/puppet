require 'semver'

Puppet::Type.type(:service).provide :upstart, :parent => :debian do
  START_ON = /^\s*start\s+on/
  COMMENTED_START_ON = /^\s*#+\s*start\s+on/
  MANUAL   = /^\s*manual\s*$/

  desc "Ubuntu service management with `upstart`.

  This provider manages `upstart` jobs on Ubuntu. For `upstart` documentation,
  see <http://upstart.ubuntu.com/>.
  "

  confine :any => [
    Facter.value(:operatingsystem) == 'Ubuntu',
    (Facter.value(:osfamily) == 'RedHat' and Facter.value(:operatingsystemrelease) =~ /^6\./),
    Facter.value(:operatingsystem) == 'Amazon',
    Facter.value(:operatingsystem) == 'LinuxMint',
  ]

  defaultfor :operatingsystem => :ubuntu, :operatingsystemmajrelease => ["10.04", "12.04", "14.04", "14.10"]

  commands :start   => "/sbin/start",
           :stop    => "/sbin/stop",
           :restart => "/sbin/restart",
           :status_exec  => "/sbin/status",
           :initctl => "/sbin/initctl"

  # upstart developer haven't implemented initctl enable/disable yet:
  # http://www.linuxplanet.com/linuxplanet/tutorials/7033/2/
  has_feature :enableable

  def self.instances
    self.get_services(self.excludes) # Take exclude list from init provider
  end

  def self.excludes
    excludes = super
    if Facter.value(:osfamily) == 'RedHat'
      # Puppet cannot deal with services that have instances, so we have to
      # ignore these services using instances on redhat based systems.
      excludes += %w[serial tty]
    end

    excludes
  end


  def self.get_services(exclude=[])
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
          elsif matcher = line.match(/^(network-interface-security)\s\(([^\)]+)\)/)
            "#{matcher[1]} JOB=#{matcher[2]}"
          else
            line.split.first
          end
        instances << new(:name => name)
      }
    }
    instances.reject { |instance| exclude.include?(instance.name) }
  end

  def self.defpath
    ["/etc/init", "/etc/init.d"]
  end

  def upstart_version
    @upstart_version ||= initctl("--version").match(/initctl \(upstart ([^\)]*)\)/)[1]
  end

  # Where is our override script?
  def overscript
    @overscript ||= initscript.gsub(/\.conf$/,".override")
  end

  def search(name)
    # Search prefers .conf as that is what upstart uses
    [".conf", "", ".sh"].each do |suffix|
      paths.each do |path|
        service_name = name.match(/^(\S+)/)[1]
        fqname = File.join(path, service_name + suffix)
        if Puppet::FileSystem.exist?(fqname)
          return fqname
        end

        self.debug("Could not find #{name}#{suffix} in #{path}")
      end
    end

    raise Puppet::Error, "Could not find init script or upstart conf file for '#{name}'"
  end

  def enabled?
    return super if not is_upstart?

    script_contents = read_script_from(initscript)
    if version_is_pre_0_6_7
      enabled_pre_0_6_7?(script_contents)
    elsif version_is_pre_0_9_0
      enabled_pre_0_9_0?(script_contents)
    elsif version_is_post_0_9_0
      enabled_post_0_9_0?(script_contents, read_override_file)
    end
  end

  def enable
    return super if not is_upstart?

    script_text = read_script_from(initscript)
    if version_is_pre_0_9_0
      enable_pre_0_9_0(script_text)
    else
      enable_post_0_9_0(script_text, read_override_file)
    end
  end

  def disable
    return super if not is_upstart?

    script_text = read_script_from(initscript)
    if version_is_pre_0_6_7
      disable_pre_0_6_7(script_text)
    elsif version_is_pre_0_9_0
      disable_pre_0_9_0(script_text)
    elsif version_is_post_0_9_0
      disable_post_0_9_0(read_override_file)
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
    if (@resource[:hasstatus] == :false) ||
        @resource[:status] ||
        ! is_upstart?
      return super
    end

    output = status_exec(@resource[:name].split)
    if output =~ /start\//
      return :running
    else
      return :stopped
    end
  end

private
  def is_upstart?(script = initscript)
    Puppet::FileSystem.exist?(script) && script.match(/\/etc\/init\/\S+\.conf/)
  end

  def version_is_pre_0_6_7
    Puppet::Util::Package.versioncmp(upstart_version, "0.6.7") == -1
  end

  def version_is_pre_0_9_0
    Puppet::Util::Package.versioncmp(upstart_version, "0.9.0") == -1
  end

  def version_is_post_0_9_0
    Puppet::Util::Package.versioncmp(upstart_version, "0.9.0") >= 0
  end

  def enabled_pre_0_6_7?(script_text)
    # Upstart version < 0.6.7 means no manual stanza.
    if script_text.match(START_ON)
      return :true
    else
      return :false
    end
  end

  def enabled_pre_0_9_0?(script_text)
    # Upstart version < 0.9.0 means no override files
    # So we check to see if an uncommented start on or manual stanza is the last one in the file
    # The last one in the file wins.
    enabled = :false
    script_text.each_line do |line|
      if line.match(START_ON)
        enabled = :true
      elsif line.match(MANUAL)
        enabled = :false
      end
    end
    enabled
  end

  def enabled_post_0_9_0?(script_text, over_text)
    # This version has manual stanzas and override files
    # So we check to see if an uncommented start on or manual stanza is the last one in the
    # conf file and any override files. The last one in the file wins.
    enabled = :false

    script_text.each_line do |line|
      if line.match(START_ON)
        enabled = :true
      elsif line.match(MANUAL)
        enabled = :false
      end
    end
    over_text.each_line do |line|
      if line.match(START_ON)
        enabled = :true
      elsif line.match(MANUAL)
        enabled = :false
      end
    end if over_text
    enabled
  end

  def enable_pre_0_9_0(text)
    # We also need to remove any manual stanzas to ensure that it is enabled
    text = remove_manual_from(text)

    if enabled_pre_0_9_0?(text) == :false
      enabled_script =
        if text.match(COMMENTED_START_ON)
          uncomment_start_block_in(text)
        else
          add_default_start_to(text)
        end
    else
      enabled_script = text
    end

    write_script_to(initscript, enabled_script)
  end

  def enable_post_0_9_0(script_text, over_text)
    over_text = remove_manual_from(over_text)

    if enabled_post_0_9_0?(script_text, over_text) == :false
      if script_text.match(START_ON)
        over_text << extract_start_on_block_from(script_text)
      else
        over_text << "\nstart on runlevel [2,3,4,5]"
      end
    end

    write_script_to(overscript, over_text)
  end

  def disable_pre_0_6_7(script_text)
    disabled_script = comment_start_block_in(script_text)
    write_script_to(initscript, disabled_script)
  end

  def disable_pre_0_9_0(script_text)
    write_script_to(initscript, ensure_disabled_with_manual(script_text))
  end

  def disable_post_0_9_0(over_text)
    write_script_to(overscript, ensure_disabled_with_manual(over_text))
  end

  def read_override_file
    if Puppet::FileSystem.exist?(overscript)
      read_script_from(overscript)
    else
      ""
    end
  end

  def uncomment(line)
    line.gsub(/^(\s*)#+/, '\1')
  end

  def remove_trailing_comments_from_commented_line_of(line)
    line.gsub(/^(\s*#+\s*[^#]*).*/, '\1')
  end

  def remove_trailing_comments_from(line)
    line.gsub(/^(\s*[^#]*).*/, '\1')
  end

  def unbalanced_parens_on(line)
    line.count('(') - line.count(')')
  end

  def remove_manual_from(text)
    text.gsub(MANUAL, "")
  end

  def comment_start_block_in(text)
    parens = 0
    text.lines.map do |line|
      if line.match(START_ON) || parens > 0
        # If there are more opening parens than closing parens, we need to comment out a multiline 'start on' stanza
        parens += unbalanced_parens_on(remove_trailing_comments_from(line))
        "#" + line
      else
        line
      end
    end.join('')
  end

  def uncomment_start_block_in(text)
    parens = 0
    text.lines.map do |line|
      if line.match(COMMENTED_START_ON) || parens > 0
        parens += unbalanced_parens_on(remove_trailing_comments_from_commented_line_of(line))
        uncomment(line)
      else
        line
      end
    end.join('')
  end

  def extract_start_on_block_from(text)
    parens = 0
    text.lines.map do |line|
      if line.match(START_ON) || parens > 0
        parens += unbalanced_parens_on(remove_trailing_comments_from(line))
        line
      end
    end.join('')
  end

  def add_default_start_to(text)
    text + "\nstart on runlevel [2,3,4,5]"
  end

  def ensure_disabled_with_manual(text)
    remove_manual_from(text) + "\nmanual"
  end

  def read_script_from(filename)
    File.open(filename) do |file|
      file.read
    end
  end

  def write_script_to(file, text)
    Puppet::Util.replace_file(file, 0644) do |f|
      f.write(text)
    end
  end
end
