require 'puppet/provider/package'
require 'puppet/provider/command'

Puppet::Type.type(:package).provide :macports, :parent => Puppet::Provider::Package do
  desc "Package management using MacPorts on OS X.

    Supports MacPorts versions and revisions, but not variants.
    Variant preferences may be specified using
    [the MacPorts variants.conf file](http://guide.macports.org/chunked/internals.configuration-files.html#internals.configuration-files.variants-conf).

    When specifying a version in the Puppet DSL, only specify the version, not the revision.
    Revisions are only used internally for ensuring the latest version/revision of a port.
  "

  confine :operatingsystem => :darwin

  has_command(:port, "/opt/local/bin/port") do
    environment :HOME => "/opt/local"
  end

  has_feature :installable
  has_feature :uninstallable
  has_feature :upgradeable
  has_feature :versionable


  def self.parse_installed_query_line(line)
    regex = /(\S+)\s+@(\S+)_(\d+).*\(active\)/
    fields = [:name, :ensure, :revision]
    hash_from_line(line, regex, fields)
  end

  def self.parse_info_query_line(line)
    regex = /(\S+)\s+(\S+)/
    fields = [:version, :revision]
    hash_from_line(line, regex, fields)
  end

  def self.hash_from_line(line, regex, fields)
    hash = {}
    if match = regex.match(line)
      fields.zip(match.captures) { |field, value|
        hash[field] = value
      }
      hash[:provider] = self.name
      return hash
    end
    nil
  end

  def self.instances
    packages = []
    port("-q", :installed).each_line do |line|
      if hash = parse_installed_query_line(line)
        packages << new(hash)
      end
    end
    packages
  end

  def install
    should = @resource.should(:ensure)
    if [:latest, :installed, :present].include?(should)
      port("-q", :install, @resource[:name])
    else
      port("-q", :install, @resource[:name], "@#{should}")
    end
    # MacPorts now correctly exits non-zero with appropriate errors in
    # situations where a port cannot be found or installed.
  end

  def query
    result = self.class.parse_installed_query_line(execute([command(:port), "-q", :installed, @resource[:name]], :failonfail => false, :combine => false))
    return {} if result.nil?
    return result
  end

  def latest
    # We need both the version and the revision to be confident
    # we've got the latest revision of a specific version
    # Note we're still not doing anything with variants here.
    info_line = execute([command(:port), "-q", :info, "--line", "--version", "--revision", @resource[:name]], :failonfail => false, :combine => false)
    return nil if info_line == ""

    if newest = self.class.parse_info_query_line(info_line)
      current = query
      # We're doing some fiddling behind the scenes here to cope with updated revisions.
      # If we're already at the latest version/revision, then just return the version
      # so the current and desired values match. Otherwise return version and revision
      # to trigger an upgrade to the latest revision.
      if newest[:version] == current[:ensure] and newest[:revision] == current[:revision]
        return current[:ensure]
      else
        return "#{newest[:version]}_#{newest[:revision]}"
      end
    end
    nil
  end

  def uninstall
    port("-q", :uninstall, @resource[:name])
  end

  def update
    install
  end
end
