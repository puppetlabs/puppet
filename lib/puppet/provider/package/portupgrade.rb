# Whole new package, so include pack stuff
require 'puppet/provider/package'

Puppet::Type.type(:package).provide :portupgrade, :parent => Puppet::Provider::Package do
  include Puppet::Util::Execution

  desc "Support for FreeBSD's ports using the portupgrade ports management software.
    Use the port's full origin as the resource name. eg (ports-mgmt/portupgrade)
    for the portupgrade port."

  ## has_features is usually autodetected based on defs below.
  # has_features :installable, :uninstallable, :upgradeable

  commands :portupgrade   => "/usr/local/sbin/portupgrade",
  :portinstall   => "/usr/local/sbin/portinstall",
  :portversion   => "/usr/local/sbin/portversion",
  :portuninstall => "/usr/local/sbin/pkg_deinstall",
  :portinfo      => "/usr/sbin/pkg_info"

  ## Activate this only once approved by someone important.
  # defaultfor :operatingsystem => :freebsd

  # Remove unwanted environment variables.
  %w{INTERACTIVE UNAME}.each do |var|
    if ENV.include?(var)
      ENV.delete(var)
    end
  end

  ######## instances sub command (builds the installed packages list)

  def self.instances
    Puppet.debug "portupgrade.rb Building packages list from installed ports"

    # regex to match output from pkg_info
    regex = %r{^(\S+)-([^-\s]+):(\S+)$}
    # Corresponding field names
    fields = [:portname, :ensure, :portorigin]
    # define Temporary hash used, packages array of hashes
    hash = Hash.new
    packages = []

    # exec command
    cmdline = ["-aoQ"]
    begin
      output = portinfo(*cmdline)
    rescue Puppet::ExecutionFailure
      raise Puppet::Error.new(output, $!)
    end

    # split output and match it and populate temp hash
    output.split("\n").each { |data|
      # reset hash to nil for each line
      hash.clear
      if match = regex.match(data)
        # Output matched regex
        fields.zip(match.captures) { |field, value|
          hash[field] = value
        }

        # populate the actual :name field from the :portorigin
        # Set :provider to this object name
        hash[:name] = hash[:portorigin]
        hash[:provider] = self.name

        # Add to the full packages listing
        packages << new(hash)
      else
        # unrecognised output from pkg_info
        Puppet.debug "portupgrade.Instances() - unable to match output: #{data}"
      end
    }

    # return the packages array of hashes
    return packages
  end

  ######## Installation sub command

  def install
    Puppet.debug "portupgrade.install() - Installation call on #{@resource[:name]}"
    # -M: yes, we're a batch, so don't ask any questions
    cmdline = ["-M BATCH=yes", @resource[:name]]

    # FIXME: it's possible that portinstall prompts for data so locks up.
    begin
      output = portinstall(*cmdline)
    rescue Puppet::ExecutionFailure
      raise Puppet::Error.new(output, $!)
    end

    if output =~ /\*\* No such /
      raise Puppet::ExecutionFailure, _("Could not find package %{name}") % { name: @resource[:name] }
    end

    # No return code required, so do nil to be clean
    return nil
  end

  ######## Latest subcommand (returns the latest version available, or current version if installed is latest)

  def latest
    Puppet.debug "portupgrade.latest() - Latest check called on #{@resource[:name]}"
    # search for latest version available, or return current version.
    # cmdline = "portversion -v <portorigin>", returns "<portname> <code> <stuff>"
    # or "** No matching package found: <portname>"
    cmdline = ["-v", @resource[:name]]

    begin
      output = portversion(*cmdline)
    rescue Puppet::ExecutionFailure
      raise Puppet::Error.new(output, $!)
    end

    # Check: output format.
    if output =~ /^\S+-([^-\s]+)\s+(\S)\s+(.*)/
      installedversion = $1
      comparison = $2
      otherdata = $3

      # Only return a new version number when it's clear that there is a new version
      # all others return the current version so no unexpected 'upgrades' occur.
      case comparison
      when "=", ">"
        Puppet.debug "portupgrade.latest() - Installed package is latest (#{installedversion})"
        return installedversion
      when "<"
        # "portpkg-1.7_5 < needs updating (port has 1.14)"
        # "portpkg-1.7_5 < needs updating (port has 1.14) (=> 'newport/pkg')
        if otherdata =~ /\(port has (\S+)\)/
          newversion = $1
          Puppet.debug "portupgrade.latest() - Installed version needs updating to (#{newversion})"
          return newversion
        else
          Puppet.debug "portupgrade.latest() - Unable to determine new version from (#{otherdata})"
          return installedversion
        end
      when "?", "!", "#"
        Puppet.debug "portupgrade.latest() - Comparison Error reported from portversion (#{output})"
        return installedversion
      else
        Puppet.debug "portupgrade.latest() - Unknown code from portversion output (#{output})"
        return installedversion
      end

    else
      # error: output not parsed correctly, error out with nil.
      # Seriously - this section should never be called in a perfect world.
      # as verification that the port is installed has already happened in query.
      if output =~ /^\*\* No matching package /
        raise Puppet::ExecutionFailure, _("Could not find package %{name}") % { name: @resource[:name] }
      else
        # Any other error (dump output to log)
        raise Puppet::ExecutionFailure, _("Unexpected output from portversion: %{output}") % { output: output }
      end

      # Just in case we still are running, return nil
      return nil
    end

    # At this point normal operation has finished and we shouldn't have been called.
    # Error out and let the admin deal with it.
    raise Puppet::Error, _("portversion.latest() - fatal error with portversion: %{output}") % { output: output }
  end

  ###### Query subcommand - return a hash of details if exists, or nil if it doesn't.
  # Used to make sure the package is installed

  def query
    Puppet.debug "portupgrade.query() - Called on #{@resource[:name]}"

    cmdline = ["-qO", @resource[:name]]
    begin
      output = portinfo(*cmdline)
    rescue Puppet::ExecutionFailure
      raise Puppet::Error.new(output, $!)
    end

    # Check: if output isn't in the right format, return nil
    if output =~ /^(\S+)-([^-\s]+)/
      # Fill in the details
      hash = Hash.new
      hash[:portorigin] = self.name
      hash[:portname]   = $1
      hash[:ensure]     = $2

      # If more details are required, then we can do another pkg_info
      # query here and parse out that output and add to the hash
      # return the hash to the caller
      return hash
    else
      Puppet.debug "portupgrade.query() - package (#{@resource[:name]}) not installed"
      return nil
    end
  end

  ####### Uninstall command

  def uninstall
    Puppet.debug "portupgrade.uninstall() - called on #{@resource[:name]}"
    # Get full package name from port origin to uninstall with
    cmdline = ["-qO", @resource[:name]]
    begin
      output = portinfo(*cmdline)
    rescue Puppet::ExecutionFailure
      raise Puppet::Error.new(output, $!)
    end

    if output =~ /^(\S+)/
      # output matches, so uninstall it
      portuninstall $1
    end
  end

  ######## Update/upgrade command

  def update
    Puppet.debug "portupgrade.update() - called on (#{@resource[:name]})"

    cmdline = ["-qO", @resource[:name]]
    begin
      output = portinfo(*cmdline)
    rescue Puppet::ExecutionFailure
      raise Puppet::Error.new(output, $!)
    end

    if output =~ /^(\S+)/
      # output matches, so upgrade the software
      cmdline = ["-M BATCH=yes", $1]
      begin
        output = portupgrade(*cmdline)
      rescue Puppet::ExecutionFailure
        raise Puppet::Error.new(output, $!)
      end
    end
  end

  ## EOF
end
