# frozen_string_literal: true

require_relative '../../../puppet/provider/package'

# Packaging on OpenBSD.  Doesn't work anywhere else that I know of.
Puppet::Type.type(:package).provide :openbsd, :parent => Puppet::Provider::Package do
  desc "OpenBSD's form of `pkg_add` support.

    This provider supports the `install_options` and `uninstall_options`
    attributes, which allow command-line flags to be passed to pkg_add and pkg_delete.
    These options should be specified as an array where each element is either a
     string or a hash."

  commands :pkginfo => "pkg_info",
           :pkgadd => "pkg_add",
           :pkgdelete => "pkg_delete"

  defaultfor 'os.name' => :openbsd
  confine 'os.name' => :openbsd

  has_feature :versionable
  has_feature :install_options
  has_feature :uninstall_options
  has_feature :upgradeable
  has_feature :supports_flavors

  mk_resource_methods

  def self.instances
    packages = []

    begin
      execpipe(listcmd) do |process|
        # our regex for matching pkg_info output
        regex = /^(.*)-(\d[^-]*)-?([\w-]*)(.*)$/
        fields = [:name, :ensure, :flavor]
        hash = {}

        # now turn each returned line into a package object
        process.each_line { |line|
          match = regex.match(line.split[0])
          if match
            fields.zip(match.captures) { |field, value|
              hash[field] = value
            }

            hash[:provider] = name

            packages << new(hash)
            hash = {}
          end
        }
      end

      packages
    rescue Puppet::ExecutionFailure
      nil
    end
  end

  def self.listcmd
    [command(:pkginfo), "-a"]
  end

  def latest
    if @resource[:flavor]
      query = "#{@resource[:name]}--#{@resource[:flavor]}"
    else
      query = @resource[:name] + "--"
    end

    output = Puppet::Util.withenv({}) { pkginfo "-Q", query }

    if output.nil? or output.size == 0 or output =~ /Error from /
      debug "Failed to query for #{resource[:name]}"
      return properties[:ensure]
    else
      # Remove all fuzzy matches first.
      output = output.split.select { |p| p =~ /^#{resource[:name]}-(\d[^-]*)-?(\w*)/ }.join
      debug "pkg_info -Q for #{resource[:name]}: #{output}"
    end

    if output =~ /^#{resource[:name]}-(\d[^-]*)-?(\w*) \(installed\)$/
      debug "Package is already the latest available"
      properties[:ensure]
    else
      match = /^(.*)-(\d[^-]*)-?(\w*)$/.match(output)
      debug "Latest available for #{resource[:name]}: #{match[2]}"

      if properties[:ensure].to_sym == :absent
        return match[2]
      end

      vcmp = properties[:ensure].split('.').map { |s|s.to_i } <=> match[2].split('.').map { |s|s.to_i }
      if vcmp > 0
        # The locally installed package may actually be newer than what a mirror
        # has. Log it at debug, but ignore it otherwise.
        debug "Package #{resource[:name]} #{properties[:ensure]} newer then available #{match[2]}"
        properties[:ensure]
      else
        match[2]
      end
    end
  end

  def update
    install(true)
  end

  def install(latest = false)
    cmd = []

    cmd << '-r'
    cmd << install_options
    cmd << get_full_name(latest)

    if latest
      cmd.unshift('-z')
    end

    # pkg_add(1) doesn't set the return value upon failure so we have to peek
    # at it's output to see if something went wrong.
    output = Puppet::Util.withenv({}) { pkgadd cmd.flatten.compact }
    pp output
    if output =~ /Can't find /
      self.fail "pkg_add returned: #{output.chomp}"
    end
  end

  def get_full_name(latest = false)
    # In case of a real update (i.e., the package already exists) then
    # pkg_add(8) can handle the flavors. However, if we're actually
    # installing with 'latest', we do need to handle the flavors. This is
    # done so we can feed pkg_add(8) the full package name to install to
    # prevent ambiguity.
    if resource[:flavor]
      # If :ensure contains a version, use that instead of looking it up.
      # This allows for installing packages with the same stem, but multiple
      # version such as postfix-VERSION-flavor.
      if @resource[:ensure].to_s =~ /(\d[^-]*)$/
        use_version = @resource[:ensure]
      else
        use_version = ''
      end
      "#{resource[:name]}-#{use_version}-#{resource[:flavor]}"
    elsif resource[:name].to_s.match(/[a-z0-9]%[0-9a-z]/i)
      "#{resource[:name]}"
    elsif !latest
      "#{resource[:name]}--"
    else
      # If :ensure contains a version, use that instead of looking it up.
      # This allows for installing packages with the same stem, but multiple
      # version such as openldap-server.
      if @resource[:ensure].to_s =~ /(\d[^-]*)$/
        use_version = @resource[:ensure]
      else
        use_version = get_version
      end

      if resource[:flavor]
        [ @resource[:name], use_version, @resource[:flavor]].join('-').gsub(/-+$/, '')
      else
        [ @resource[:name], use_version ]
      end
    end
  end

  def get_version
    pkg_search_name = @resource[:name]
    unless pkg_search_name.match(/[a-z0-9]%[0-9a-z]/i) and !@resource[:flavor]
      # we are only called when no flavor is specified
      # so append '--' to the :name to avoid patch versions on flavors
      pkg_search_name << "--"
    end
    # our regex for matching pkg_info output
    regex = /^(.*)-(\d[^-]*)[-]?(\w*)(.*)$/
    master_version = 0
    version = -1

    # pkg_info -I might return multiple lines, i.e. flavors
    matching_pkgs = pkginfo("-I", "pkg_search_name")
    matching_pkgs.each_line do |line|
      if match = regex.match(line.split[0])
        # now we return the first version, unless ensure is latest
        version = match.captures[1]
        return version unless @resource[:ensure] == "latest"
        master_version = version unless master_version > version
      end
    end

    return master_version unless master_version == 0
    return '' if version == -1
    raise Puppet::Error, _("%{version} is not available for this package") % { version: version }
 
  rescue Puppet::ExecutionFailure
    nil
  end

  def query
    # Search for the version info
    if pkginfo(@resource[:name]) =~ /Information for (inst:)?#{@resource[:name]}-(\S+)/
      { :ensure => Regexp.last_match(2) }
    else
      nil
    end
  end

  def install_options
    join_options(resource[:install_options])
  end

  def uninstall_options
    [join_options(resource[:uninstall_options])]
  end

  def uninstall
    pkgdelete uninstall_options.flatten.compact, @resource[:name]
  end

  def purge
    pkgdelete "-c", "-q", @resource[:name]
  end

  def flavor
    @property_hash[:flavor]
  end

  def flavor=(value)
    if flavor != @resource.should(:flavor)
      uninstall
      install
    end
  end
end
