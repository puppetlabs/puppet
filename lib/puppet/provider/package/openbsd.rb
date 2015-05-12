require 'puppet/provider/package'

# Packaging on OpenBSD.  Doesn't work anywhere else that I know of.
Puppet::Type.type(:package).provide :openbsd, :parent => Puppet::Provider::Package do
  desc "OpenBSD's form of `pkg_add` support.

    This provider supports the `install_options` and `uninstall_options`
    attributes, which allow command-line flags to be passed to pkg_add and pkg_delete.
    These options should be specified as a string (e.g. '--flag'), a hash (e.g. {'--flag' => 'value'}),
    or an array where each element is either a string or a hash."

  commands :pkginfo   => "pkg_info",
           :pkgadd    => "pkg_add",
           :pkgdelete => "pkg_delete"

  defaultfor :operatingsystem => :openbsd
  confine :operatingsystem => :openbsd

  has_feature :versionable
  has_feature :install_options
  has_feature :uninstall_options
  has_feature :upgradeable

  def self.instances
    packages = []

    begin
      execpipe(listcmd) do |process|
        # our regex for matching pkg_info output
        regex = /^(.*)-(\d[^-]*)[-]?(\w*)(.*)$/
        fields = [:name, :ensure, :flavor ]
        hash = {}

        # now turn each returned line into a package object
        process.each_line { |line|
          if match = regex.match(line.split[0])
            fields.zip(match.captures) { |field,value|
              hash[field] = value
            }

            hash[:provider] = self.name

            packages << new(hash)
            hash = {}
          else
            unless line =~ /Updating the pkgdb/
              # Print a warning on lines we can't match, but move
              # on, since it should be non-fatal
              warning("Failed to match line #{line}")
            end
          end
        }
      end

      return packages
    rescue Puppet::ExecutionFailure
      return nil
    end
  end

  def self.listcmd
    [command(:pkginfo), "-a"]
  end

  def latest
    parse_pkgconf

    if @resource[:source][-1,1] == ::File::SEPARATOR
      e_vars = { 'PKG_PATH' => @resource[:source] }
    else
      e_vars = {}
    end

    if @resource[:flavor]
      query = "#{@resource[:name]}--#{@resource[:flavor]}"
    else
      query = @resource[:name]
    end

    output = Puppet::Util.withenv(e_vars) {pkginfo "-Q", query}
    version = properties[:ensure]

    if output.nil? or output.size == 0 or output =~ /Error from /
      debug "Failed to query for #{resource[:name]}"
      return version
    else
      # Remove all fuzzy matches first.
      output = output.split.select {|p| p =~ /^#{resource[:name]}-(\d[^-]*)[-]?(\w*)/ }.join
      debug "pkg_info -Q for #{resource[:name]}: #{output}"
    end

    if output =~ /^#{resource[:name]}-(\d[^-]*)[-]?(\w*) \(installed\)$/
      debug "Package is already the latest available"
      return version
    else
      match = /^(.*)-(\d[^-]*)[-]?(\w*)$/.match(output)
      debug "Latest available for #{resource[:name]}: #{match[2]}"

      if version.to_sym == :absent || version.to_sym == :purged
        return match[2]
      end

      vcmp = version.split('.').map{|s|s.to_i} <=> match[2].split('.').map{|s|s.to_i}
      if vcmp > 0
        # The locally installed package may actually be newer than what a mirror
        # has. Log it at debug, but ignore it otherwise.
        debug "Package #{resource[:name]} #{version} newer then available #{match[2]}"
        return version
      else
        return match[2]
      end
    end
  end

  def update
    self.install(true)
  end

  def parse_pkgconf
    unless @resource[:source]
      if Puppet::FileSystem.exist?("/etc/pkg.conf")
        File.open("/etc/pkg.conf", "rb").readlines.each do |line|
          if matchdata = line.match(/^installpath\s*=\s*(.+)\s*$/i)
            @resource[:source] = matchdata[1]
          elsif matchdata = line.match(/^installpath\s*\+=\s*(.+)\s*$/i)
            if @resource[:source].nil?
              @resource[:source] = matchdata[1]
            else
              @resource[:source] += ":" + matchdata[1]
            end
          end
        end

        unless @resource[:source]
          raise Puppet::Error,
          "No valid installpath found in /etc/pkg.conf and no source was set"
        end
      else
        raise Puppet::Error,
        "You must specify a package source or configure an installpath in /etc/pkg.conf"
      end
    end
  end

  def install(latest = false)
    cmd = []

    parse_pkgconf

    if @resource[:source][-1,1] == ::File::SEPARATOR
      e_vars = { 'PKG_PATH' => @resource[:source] }
      full_name = get_full_name(latest)
    else
      e_vars = {}
      full_name = @resource[:source]
    end

    cmd << install_options
    cmd << full_name

    if latest
      cmd.unshift('-rz')
    end

    Puppet::Util.withenv(e_vars) { pkgadd cmd.flatten.compact }
  end

  def get_full_name(latest = false)
    # In case of a real update (i.e., the package already exists) then
    # pkg_add(8) can handle the flavors. However, if we're actually
    # installing with 'latest', we do need to handle the flavors. This is
    # done so we can feed pkg_add(8) the full package name to install to
    # prevent ambiguity.
    if latest && resource[:flavor]
      "#{resource[:name]}--#{resource[:flavor]}"
    elsif latest
      # Don't depend on get_version for updates.
      @resource[:name]
    else
      # If :ensure contains a version, use that instead of looking it up.
      # This allows for installing packages with the same stem, but multiple
      # version such as openldap-server.
      if /(\d[^-]*)$/.match(@resource[:ensure].to_s)
        use_version = @resource[:ensure]
      else
        use_version = get_version
      end

      [ @resource[:name], use_version, @resource[:flavor]].join('-').gsub(/-+$/, '')
    end
  end

  def get_version
    execpipe([command(:pkginfo), "-I", @resource[:name]]) do |process|
      # our regex for matching pkg_info output
      regex = /^(.*)-(\d[^-]*)[-]?(\w*)(.*)$/
      master_version = 0
      version = -1

      process.each_line do |line|
        if match = regex.match(line.split[0])
          # now we return the first version, unless ensure is latest
          version = match.captures[1]
          return version unless @resource[:ensure] == "latest"

          master_version = version unless master_version > version
        end
      end

      return master_version unless master_version == 0
      return '' if version == -1
      raise Puppet::Error, "#{version} is not available for this package"
    end
  rescue Puppet::ExecutionFailure
    return nil
  end

  def query
    # Search for the version info
    if pkginfo(@resource[:name]) =~ /Information for (inst:)?#{@resource[:name]}-(\S+)/
      return { :ensure => $2 }
    else
      return nil
    end
  end

  def install_options
    join_options(resource[:install_options])
  end

  def uninstall_options
    join_options(resource[:uninstall_options])
  end

  def uninstall
    pkgdelete uninstall_options.flatten.compact, @resource[:name]
  end

  def purge
    pkgdelete "-c", "-q", @resource[:name]
  end
end
