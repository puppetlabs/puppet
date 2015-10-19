require 'puppet/provider/package'
require 'puppet/util/package'

Puppet::Type.type(:package).provide :nim, :parent => :aix, :source => :aix do
  desc "Installation from an AIX NIM LPP source.  The `source` parameter is required
      for this provider, and should specify the name of a NIM `lpp_source` resource
      that is visible to the puppet agent machine.  This provider supports the
      management of both BFF/installp and RPM packages.

      Note that package downgrades are *not* supported; if your resource specifies
      a specific version number and there is already a newer version of the package
      installed on the machine, the resource will fail with an error message."

  # The commands we are using on an AIX box are installed standard
  # (except nimclient) nimclient needs the bos.sysmgt.nim.client fileset.
  commands    :nimclient  => "/usr/sbin/nimclient",
              :lslpp      => "/usr/bin/lslpp",
              :rpm        => "rpm"

  # If NIM has not been configured, /etc/niminfo will not be present.
  # However, we have no way of knowing if the NIM server is not configured
  # properly.
  confine  :exists => "/etc/niminfo"

  has_feature :versionable

  attr_accessor :latest_info



  def self.srclistcmd(source)
    [ command(:nimclient), "-o", "showres", "-a", "installp_flags=L", "-a", "resource=#{source}" ]
  end

  def uninstall
    output = lslpp("-qLc", @resource[:name]).split(':')
    # the 6th index in the colon-delimited output contains a " " for installp/BFF
    # packages, and an "R" for RPMS.  (duh.)
    pkg_type = output[6]

    case pkg_type
    when " "
      installp "-gu", @resource[:name]
    when "R"
      rpm "-e", @resource[:name]
    else
      self.fail("Unrecognized AIX package type identifier: '#{pkg_type}'")
    end

    # installp will return an exit code of zero even if it didn't uninstall
    # anything... so let's make sure it worked.
    unless query().nil?
      self.fail "Failed to uninstall package '#{@resource[:name]}'"
    end
  end

  def install(useversion = true)
    unless source = @resource[:source]
      self.fail "An LPP source location is required in 'source'"
    end

    pkg = @resource[:name]

    version_specified = (useversion and (! @resource.should(:ensure).is_a? Symbol))

    # This is unfortunate for a couple of reasons.  First, because of a subtle
    # difference in the command-line syntax for installing an RPM vs an
    # installp/BFF package, we need to know ahead of time which type of
    # package we're trying to install.  This means we have to execute an
    # extra command.
    #
    # Second, the command is easiest to deal with and runs fastest if we
    # pipe it through grep on the shell.  Unfortunately, the way that
    # the provider `make_command_methods` metaprogramming works, we can't
    # use that code path to execute the command (because it treats the arguments
    # as an array of args that all apply to `nimclient`, which fails when you
    # hit the `|grep`.)  So here we just call straight through to P::U.execute
    # with a single string argument for the full command, rather than going
    # through the metaprogrammed layer.  We could get rid of the grep and
    # switch back to the metaprogrammed stuff, and just parse all of the output
    # in Ruby... but we'd be doing an awful lot of unnecessary work.
    showres_command = "/usr/sbin/nimclient -o showres -a resource=#{source} |/usr/bin/grep -p -E "
    if (version_specified)
      version = @resource.should(:ensure)
      showres_command << "'#{Regexp.escape(pkg)}( |-)#{Regexp.escape(version)}'"
    else
      version = nil
      showres_command << "'#{Regexp.escape(pkg)}'"
    end
    output = Puppet::Util::Execution.execute(showres_command)


    if (version_specified)
      package_type = determine_package_type(output, pkg, version)
    else
      package_type, version = determine_latest_version(output, pkg)
    end

    if (package_type == nil)
      errmsg = "Unable to find package '#{pkg}' "
      if (version_specified)
        errmsg << "with version '#{version}' "
      end
      errmsg << "on lpp_source '#{source}'"
      self.fail errmsg
    end

    # This part is a bit tricky.  If there are multiple versions of the
    # package available, then `version` will be set to a value, and we'll need
    # to add that value to our installation command.  However, if there is only
    # one version of the package available, `version` will be set to `nil`, and
    # we don't need to add the version string to the command.
    if (version)
      # Now we know if the package type is RPM or not, and we can adjust our
      # `pkg` string for passing to the install command accordingly.
      if (package_type == :rpm)
        # RPM's expect a hyphen between the package name and the version number
        version_separator = "-"
      else
        # installp/BFF packages expect a space between the package name and the
        # version number.
        version_separator = " "
      end

      pkg += version_separator + version
    end

    # NOTE: the installp flags here are ignored (but harmless) for RPMs
    output = nimclient "-o", "cust", "-a", "installp_flags=acgwXY", "-a", "lpp_source=#{source}", "-a", "filesets=#{pkg}"

    # If the package is superseded, it means we're trying to downgrade and we
    # can't do that.
    case package_type
    when :installp
      if output =~ /^#{Regexp.escape(@resource[:name])}\s+.*\s+Already superseded by.*$/
        self.fail "NIM package provider is unable to downgrade packages"
      end
    when :rpm
      if output =~ /^#{Regexp.escape(@resource[:name])}.* is superseded by.*$/
        self.fail "NIM package provider is unable to downgrade packages"
      end
    end
  end


  private

  ## UTILITY METHODS FOR PARSING `nimclient -o showres` output

  # This makes me very sad.  These regexes seem pretty fragile, but
  # I spent a lot of time trying to figure out a solution that didn't
  # require parsing the `nimclient -o showres` output and was unable to
  # do so.
  self::HEADER_LINE_REGEX      = /^([^\s]+)\s+[^@]+@@(I|R):(\1)\s+[^\s]+$/
  self::PACKAGE_LINE_REGEX     = /^.*@@(I|R):(.*)$/
  self::RPM_PACKAGE_REGEX      = /^(.*)-(.*-\d+) \2$/
  self::INSTALLP_PACKAGE_REGEX = /^(.*) (.*)$/

  # Here is some sample output that shows what the above regexes will be up
  # against:
  # FOR AN INSTALLP PACKAGE:
  #
  #    mypackage.foo                                                           ALL  @@I:mypackage.foo _all_filesets
  #    @ 1.2.3.1  MyPackage Runtime Environment                       @@I:mypackage.foo 1.2.3.1
  #    + 1.2.3.4  MyPackage Runtime Environment                       @@I:mypackage.foo 1.2.3.4
  #    + 1.2.3.8  MyPackage Runtime Environment                       @@I:mypackage.foo 1.2.3.8
  #
  # FOR AN RPM PACKAGE:
  #
  # mypackage.foo                                                                ALL  @@R:mypackage.foo _all_filesets
  #   @@R:mypackage.foo-1.2.3-1 1.2.3-1
  #   @@R:mypackage.foo-1.2.3-4 1.2.3-4
  #   @@R:mypackage.foo-1.2.3-8 1.2.3-8


  # Parse the output of a `nimclient -o showres` command.  Returns a two-dimensional
  # hash, where the first-level keys are package names, the second-level keys are
  # version number strings for all of the available version numbers for a package,
  # and the values indicate the package type (:rpm / :installp)
  def parse_showres_output(showres_output)
    paragraphs = split_into_paragraphs(showres_output)
    packages = {}
    paragraphs.each do |para|
      lines = para.split(/$/)
      parse_showres_header_line(lines.shift)
      lines.each do |l|
        package, version, type = parse_showres_package_line(l)
        packages[package] ||= {}
        packages[package][version] = type
      end
    end
    packages
  end

  # This method basically just splits the multi-line input string into chunks
  # based on lines that contain nothing but whitespace.  It also strips any
  # leading or trailing whitespace (including newlines) from the resulting
  # strings and then returns them as an array.
  def split_into_paragraphs(showres_output)
    showres_output.split(/^\s*$/).map { |p| p.strip! }
  end

  def parse_showres_header_line(line)
    # This method doesn't produce any meaningful output; it's basically just
    # meant to validate that the header line for the package listing output
    # looks sane, so we know we're dealing with the kind of output that we
    # are capable of handling.
    unless line.match(self.class::HEADER_LINE_REGEX)
      self.fail "Unable to parse output from nimclient showres: line does not match expected package header format:\n'#{line}'"
    end
  end

  def parse_installp_package_string(package_string)
    unless match = package_string.match(self.class::INSTALLP_PACKAGE_REGEX)
      self.fail "Unable to parse output from nimclient showres: package string does not match expected installp package string format:\n'#{package_string}'"
    end
    package_name = match.captures[0]
    version = match.captures[1]
    [package_name, version, :installp]
  end

  def parse_rpm_package_string(package_string)
    unless match = package_string.match(self.class::RPM_PACKAGE_REGEX)
      self.fail "Unable to parse output from nimclient showres: package string does not match expected rpm package string format:\n'#{package_string}'"
    end
    package_name = match.captures[0]
    version = match.captures[1]
    [package_name, version, :rpm]
  end

  def parse_showres_package_line(line)
    unless match = line.match(self.class::PACKAGE_LINE_REGEX)
      self.fail "Unable to parse output from nimclient showres: line does not match expected package line format:\n'#{line}'"
    end

    package_type_flag = match.captures[0]
    package_string = match.captures[1]

    case package_type_flag
      when "I"
        parse_installp_package_string(package_string)
      when "R"
        parse_rpm_package_string(package_string)
      else
        self.fail "Unrecognized package type specifier: '#{package_type_flag}' in package line:\n'#{line}'"
    end
  end

  # Given a blob of output from `nimclient -o showres` and a package name,
  # this method checks to see if there are multiple versions of the package
  # available on the lpp_source.  If there are, the method returns
  # [package_type, latest_version] (where package_type is one of :installp or :rpm).
  # If there is only one version of the package available, it returns
  # [package_type, nil], because the caller doesn't need to pass the version
  # string to the command-line command if there is only one version available.
  # If the package is not available at all, the method simply returns nil (instead
  # of a tuple).
  def determine_latest_version(showres_output, package_name)
    packages = parse_showres_output(showres_output)
    unless packages.has_key?(package_name)
      return nil
    end
    if (packages[package_name].count == 1)
      version = packages[package_name].keys[0]
      return packages[package_name][version], nil
    else
      versions = packages[package_name].keys
      latest_version = (versions.sort { |a, b| Puppet::Util::Package.versioncmp(b, a) })[0]
      return packages[package_name][latest_version], latest_version
    end
  end

  def determine_package_type(showres_output, package_name, version)
    packages = parse_showres_output(showres_output)
    unless (packages.has_key?(package_name) and packages[package_name].has_key?(version))
      return nil
    end
    packages[package_name][version]
  end
end
