Puppet::Type.type(:package).provide :zypper, :parent => :rpm do
  desc "Support for SuSE `zypper` package manager. Found in SLES10sp2+ and SLES11"

  has_feature :versionable, :install_options

  commands :zypper => "/usr/bin/zypper"

  confine    :operatingsystem => [:suse, :sles, :sled, :opensuse]

  #on zypper versions <1.0, the version option returns 1
  #some versions of zypper output on stderr
  def zypper_version
    cmd = [self.class.command(:zypper),"--version"]
    execute(cmd, { :failonfail => false, :combine => true})
  end

  # Install a package using 'zypper'.
  def install
    should = @resource.should(:ensure)
    self.debug "Ensuring => #{should}"
    wanted = @resource[:name]

    # XXX: We don't actually deal with epochs here.
    case should
    when true, false, Symbol
      # pass
    else
      # Add the package version
      wanted = "#{wanted}-#{should}"
    end

    #This has been tested with following zypper versions
    #SLE 10.2: 0.6.104
    #SLE 11.0: 1.0.8
    #OpenSuse 10.2: 0.6.13
    #OpenSuse 11.2: 1.2.8
    #Assume that this will work on newer zypper versions

    #extract version numbers and convert to integers
    major, minor, patch = zypper_version.scan(/\d+/).map{ |x| x.to_i }
    self.debug "Detected zypper version #{major}.#{minor}.#{patch}"

    #zypper version < 1.0 does not support --quiet flag
    quiet = "--quiet"
    if major < 1
      quiet = "--terse"
    end

    license = "--auto-agree-with-licenses"
    noconfirm = "--no-confirm"

    #zypper 0.6.13 (OpenSuSE 10.2) does not support auto agree with licenses
    if major < 1 and minor <= 6 and patch <= 13
      zypper quiet, :install, noconfirm, install_options, wanted
    else
      zypper quiet, :install, license, noconfirm, install_options, wanted
    end

    unless self.query
      raise Puppet::ExecutionFailure.new(
        "Could not find package #{self.name}"
      )
    end
  end

  # What's the latest package version available?
  def latest
    #zypper can only get a list of *all* available packages?
    output = zypper "list-updates"

    if output =~ /#{Regexp.escape @resource[:name]}\s*\|.*?\|\s*([^\s\|]+)/
      return $1
    else
      # zypper didn't find updates, pretend the current
      # version is the latest
      return @property_hash[:ensure]
    end
  end

  def update
    # zypper install can be used for update, too
    self.install
  end

  def install_options
    join_options(resource[:install_options])
  end

  def join_options(options)
    return unless options

    options.collect do |val|
      case val
      when Hash
        val.keys.sort.collect do |k|
          "#{k} '#{val[k]}'"
        end.join(' ')
      else
        val
      end
    end
  end
end
