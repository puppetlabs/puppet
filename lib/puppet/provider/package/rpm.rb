require 'puppet/provider/package'

# RPM packaging.  Should work anywhere that has rpm installed.
Puppet::Type.type(:package).provide :rpm, :source => :rpm, :parent => Puppet::Provider::Package do
  desc "RPM packaging support; should work anywhere with a working `rpm`
    binary.

    This provider supports the `install_options` and `uninstall_options`
    attributes, which allow command-line flags to be passed to rpm.
    These options should be specified as a string (e.g. '--flag'), a hash (e.g. {'--flag' => 'value'}),
    or an array where each element is either a string or a hash."

  has_feature :versionable
  has_feature :install_options
  has_feature :uninstall_options
  has_feature :virtual_packages

  # Note: self:: is required here to keep these constants in the context of what will
  # eventually become this Puppet::Type::Package::ProviderRpm class.
  # The query format by which we identify installed packages
  self::NEVRA_FORMAT = %Q{%{NAME} %|EPOCH?{%{EPOCH}}:{0}| %{VERSION} %{RELEASE} %{ARCH}\\n}
  self::NEVRA_REGEX  = %r{^(\S+) (\S+) (\S+) (\S+) (\S+)$}
  self::NEVRA_FIELDS = [:name, :epoch, :version, :release, :arch]

  commands :rpm => "rpm"

  if command('rpm')
    confine :true => begin
      rpm('--version')
      rescue Puppet::ExecutionFailure
        false
      else
        true
      end
  end

  def self.current_version
    return @current_version unless @current_version.nil?
    output = rpm "--version"
    @current_version = output.gsub('RPM version ', '').strip
  end

  # rpm < 4.1 does not support --nosignature
  def self.nosignature
    '--nosignature' unless Puppet::Util::Package.versioncmp(current_version, '4.1') < 0
  end

  # rpm < 4.0.2 does not support --nodigest
  def self.nodigest
    '--nodigest' unless Puppet::Util::Package.versioncmp(current_version, '4.0.2') < 0
  end

  def self.instances
    packages = []

    # list out all of the packages
    begin
      execpipe("#{command(:rpm)} -qa #{nosignature} #{nodigest} --qf '#{self::NEVRA_FORMAT}'") { |process|
        # now turn each returned line into a package object
        process.each_line { |line|
          hash = nevra_to_hash(line)
          packages << new(hash) unless hash.empty?
        }
      }
    rescue Puppet::ExecutionFailure
      raise Puppet::Error, "Failed to list packages", $!.backtrace
    end

    packages
  end

  # Find the fully versioned package name and the version alone. Returns
  # a hash with entries :instance => fully versioned package name, and
  # :ensure => version-release
  def query
    #NOTE: Prior to a fix for issue 1243, this method potentially returned a cached value
    #IF YOU CALL THIS METHOD, IT WILL CALL RPM
    #Use get(:property) to check if cached values are available
    cmd = ["-q",  @resource[:name], "#{self.class.nosignature}", "#{self.class.nodigest}", "--qf", self.class::NEVRA_FORMAT]

    begin
      output = rpm(*cmd)
    rescue Puppet::ExecutionFailure
      return nil unless @resource.allow_virtual?

      # rpm -q exits 1 if package not found
      # retry the query for virtual packages
      cmd << '--whatprovides'
      begin
        output = rpm(*cmd)
      rescue Puppet::ExecutionFailure
        # couldn't find a virtual package either
        return nil
      end
    end
    # FIXME: We could actually be getting back multiple packages
    # for multilib and this will only return the first such package
    @property_hash.update(self.class.nevra_to_hash(output))

    @property_hash.dup
  end

  # Here we just retrieve the version from the file specified in the source.
  def latest
    unless source = @resource[:source]
      @resource.fail "RPMs must specify a package source"
    end

    cmd = [command(:rpm), "-q", "--qf", self.class::NEVRA_FORMAT, "-p", source]
    h = self.class.nevra_to_hash(execfail(cmd, Puppet::Error))
    h[:ensure]
  end

  def install
    unless source = @resource[:source]
      @resource.fail "RPMs must specify a package source"
    end

    version =  @property_hash[:ensure]

    # RPM gets upset if you try to install an already installed package
    return if @resource.should(:ensure) == version || (@resource.should(:ensure) == :latest && version == latest)

    flag = ["-i"]
    flag = ["-U", "--oldpackage"] if version && (version != :absent && version != :purged)
    flag += install_options if resource[:install_options]
    rpm flag, source
  end

  def uninstall
    query if get(:arch) == :absent
    nvr = "#{get(:name)}-#{get(:version)}-#{get(:release)}"
    arch = ".#{get(:arch)}"
    # If they specified an arch in the manifest, erase that Otherwise,
    # erase the arch we got back from the query. If multiple arches are
    # installed and only the package name is specified (without the
    # arch), this will uninstall all of them on successive runs of the
    # client, one after the other

    # version of RPM prior to 4.2.1 can't accept the architecture as
    # part of the package name.
    unless Puppet::Util::Package.versioncmp(self.class.current_version, '4.2.1') < 0
      if @resource[:name][-arch.size, arch.size] == arch
        nvr += arch
      else
        nvr += ".#{get(:arch)}"
      end
    end

    flag = ['-e']
    flag += uninstall_options if resource[:uninstall_options]
    rpm flag, nvr
  end

  def update
    self.install
  end

  def install_options
    join_options(resource[:install_options])
  end

  def uninstall_options
    join_options(resource[:uninstall_options])
  end

  # This is an attempt at implementing RPM's
  # lib/rpmvercmp.c rpmvercmp(a, b) in Ruby.
  #
  # Some of the things in here look REALLY
  # UGLY and/or arbitrary. Our goal is to
  # match how RPM compares versions, quirks
  # and all.
  #
  # I've kept a lot of C-like string processing
  # in an effort to keep this as identical to RPM
  # as possible.
  #
  # returns 1 if str1 is newer than str2,
  #         0 if they are identical
  #        -1 if str1 is older than str2
  def rpmvercmp(str1, str2)
    return 0 if str1 == str2

    front_strip_re = /^[^A-Za-z0-9~]+/

    while str1.length > 0 or str2.length > 0
      # trim anything that's in front_strip_re and != '~' off the beginning of each string
      str1 = str1.gsub(front_strip_re, '')
      str2 = str2.gsub(front_strip_re, '')

      # "handle the tilde separator, it sorts before everything else"
      if /^~/.match(str1) && /^~/.match(str2)
        # if they both have ~, strip it
        str1 = str1[1..-1]
        str2 = str2[1..-1]
      elsif /^~/.match(str1)
        return -1
      elsif /^~/.match(str2)
        return 1
      end

      break if str1.length == 0 or str2.length == 0

      # "grab first completely alpha or completely numeric segment"
      isnum = false
      # if the first char of str1 is a digit, grab the chunk of continuous digits from each string
      if /^[0-9]+/.match(str1)
        if str1 =~ /^[0-9]+/
          segment1 = $~.to_s
          str1 = $~.post_match
        else
          segment1 = ''
        end
        if str2 =~ /^[0-9]+/
          segment2 = $~.to_s
          str2 = $~.post_match
        else
          segment2 = ''
        end
        isnum = true
      # else grab the chunk of continuous alphas from each string (which may be '')
      else
        if str1 =~ /^[A-Za-z]+/
          segment1 = $~.to_s
          str1 = $~.post_match
        else
          segment1 = ''
        end
        if str2 =~ /^[A-Za-z]+/
          segment2 = $~.to_s
          str2 = $~.post_match
        else
          segment2 = ''
        end
      end

      # if the segments we just grabbed from the strings are different types (i.e. one numeric one alpha),
      # where alpha also includes ''; "numeric segments are always newer than alpha segments"
      if segment2.length == 0
        return 1 if isnum
        return -1
      end

      if isnum
        # "throw away any leading zeros - it's a number, right?"
        segment1 = segment1.gsub(/^0+/, '')
        segment2 = segment2.gsub(/^0+/, '')
        # "whichever number has more digits wins"
        return 1 if segment1.length > segment2.length
        return -1 if segment1.length < segment2.length
      end

      # "strcmp will return which one is greater - even if the two segments are alpha
      # or if they are numeric. don't return if they are equal because there might
      # be more segments to compare"
      rc = segment1 <=> segment2
      return rc if rc != 0
    end #end while loop

    # if we haven't returned anything yet, "whichever version still has characters left over wins"
    if str1.length > str2.length
      return 1
    elsif str1.length < str2.length
      return -1
    else
      return 0
    end
  end

  private
  # @param line [String] one line of rpm package query information
  # @return [Hash] of NEVRA_FIELDS strings parsed from package info
  # or an empty hash if we failed to parse
  # @api private
  def self.nevra_to_hash(line)
    line.strip!
    hash = {}

    if match = self::NEVRA_REGEX.match(line)
      self::NEVRA_FIELDS.zip(match.captures) { |f, v| hash[f] = v }
      hash[:provider] = self.name
      hash[:ensure] = "#{hash[:version]}-#{hash[:release]}"
    else
      Puppet.debug("Failed to match rpm line #{line}")
    end

    return hash
  end
end
