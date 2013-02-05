require 'puppet/provider/package'
require 'puppet/util/package'

Puppet::Type.type(:package).provide :nim, :parent => :aix, :source => :aix do
  desc "Installation from NIM LPP source."

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

    if (useversion and (! @resource.should(:ensure).is_a? Symbol))
      version = @resource.should(:ensure)
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
      output = Puppet::Util.execute("nimclient -o showres -a resource=#{source} |grep -p -E '#{Regexp.escape(pkg)}( |-)#{Regexp.escape(version)}'")

      package_type = determine_package_type(output, pkg, version)

      # Now we know if the package type is RPM or not, and we can adjust our
      # `pkg` string for passing to the install command accordingly.
      if (package_type == nil)
        self.fail "Unable to find package '#{pkg}' with version '#{version}' on lpp_source '#{source}'"
      elsif (package_type == :rpm)
        # RPM's expect a hyphen between the package name and the version number
        version_separator = "-"
      else
        # installp/BFF packages expect a space between the package name and the
        # version number.
        version_separator = " "
      end

      pkg << version_separator << version
    end

    nimclient "-o", "cust", "-a", "installp_flags=acgwXY", "-a", "lpp_source=#{source}", "-a", "filesets=#{pkg}"
  end


  private

  ## UTILITY METHODS FOR PARSING `nimclient -o showres` output

  # This makes me very sad.  These regexes seem pretty fragile, but
  # I spent a lot of time trying to figure out a solution that didn't
  # require parsing the `nimclient -o showres` output and was unable to
  # do so.
  HEADER_LINE_REGEX      = /^([^\s]+)\s+[^@]+@@(I|R):(\1)\s+[^\s]+$/
  PACKAGE_LINE_REGEX     = /^.*@@(I|R):(.*)$/
  RPM_PACKAGE_REGEX      = /^(.*)-(.*-\d+) \2$/
  INSTALLP_PACKAGE_REGEX = /^(.*) (.*)$/


  # Parse the output of a `nimclient -o showres` command.  Returns a two-dimensional
  # hash, where the first-level keys are package names, the second-level keys are
  # version number strings for all of the available version numbers for a package,
  # and the values indicate the package type (:rpm / :installp)
  def parse_showres_output(showres_output)
    paragraphs = showres_output.split(/^\s*$/).map { |p| p.strip! }
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

  def parse_showres_header_line(line)
    # This method doesn't produce any meaningful output; it's basically just
    # meant to validate that the header line for the package listing output
    # looks sane, so we know we're dealing with the kind of output that we
    # are capable of handling.
    unless line.match(HEADER_LINE_REGEX)
      self.fail "Unable to parse output from nimclient showres: line does not match expected package header format:\n'#{line}'"
    end
  end

  def parse_installp_package_string(package_string)
    unless match = package_string.match(INSTALLP_PACKAGE_REGEX)
      self.fail "Unable to parse output from nimclient showres: package string does not match expected installp package string format:\n'#{package_string}'"
    end
    package_name = match.captures[0]
    version = match.captures[1]
    [package_name, version, :installp]
  end

  def parse_rpm_package_string(package_string)
    unless match = package_string.match(RPM_PACKAGE_REGEX)
      self.fail "Unable to parse output from nimclient showres: package string does not match expected rpm package string format:\n'#{package_string}'"
    end
    package_name = match.captures[0]
    version = match.captures[1]
    [package_name, version, :rpm]
  end

  def parse_showres_package_line(line)
    unless match = line.match(PACKAGE_LINE_REGEX)
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


  def determine_package_type(showres_output, package_name, version)
    packages = parse_showres_output(showres_output)
    unless (packages.has_key?(package_name) and packages[package_name].has_key?(version))
      return nil
    end
    packages[package_name][version]
  end
end
