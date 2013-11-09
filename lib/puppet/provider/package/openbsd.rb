require 'puppet/provider/package'

# Packaging on OpenBSD.  Doesn't work anywhere else that I know of.
Puppet::Type.type(:package).provide :openbsd, :parent => Puppet::Provider::Package do
  desc "OpenBSD's form of `pkg_add` support."

  commands :pkginfo => "pkg_info", :pkgadd => "pkg_add", :pkgdelete => "pkg_delete"

  defaultfor :operatingsystem => :openbsd
  confine :operatingsystem => :openbsd

  has_feature :versionable
  has_feature :install_options
  has_feature :uninstall_options

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
            # Print a warning on lines we can't match, but move
            # on, since it should be non-fatal
            warning("Failed to match line #{line}")
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

  def parse_pkgconf
    unless @resource[:source]
      if Puppet::FileSystem::File.exist?("/etc/pkg.conf")
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

  def install
    cmd = []

    parse_pkgconf

    if @resource[:source][-1,1] == ::File::SEPARATOR
      e_vars = { 'PKG_PATH' => @resource[:source] }
      full_name = [ @resource[:name], get_version || @resource[:ensure], @resource[:flavor] ].join('-').chomp('-').chomp('-')
    else
      e_vars = {}
      full_name = @resource[:source]
    end

    cmd << install_options
    cmd << full_name

    Puppet::Util.withenv(e_vars) { pkgadd cmd.flatten.compact.join(' ') }
  end

  def get_version
    execpipe([command(:pkginfo), "-I", @resource[:name]]) do |process|
      # our regex for matching pkg_info output
      regex = /^(.*)-(\d[^-]*)[-]?(\D*)(.*)$/
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

  # Turns a array of options into flags to be passed to pkg_add(8) and
  # pkg_delete(8). The options can be passed as a string or hash. Note
  # that passing a hash should only be used in case -Dfoo=bar must be passed,
  # which can be accomplished with:
  #     install_options => [ { '-Dfoo' => 'bar' } ]
  # Regular flags like '-L' must be passed as a string.
  # @param options [Array]
  # @return Concatenated list of options
  # @api private
  def join_options(options)
    return unless options

    options.collect do |val|
      case val
      when Hash
        val.keys.sort.collect do |k|
          "#{k}=#{val[k]}"
        end.join(' ')
      else
        val
      end
    end
  end

  def uninstall
    pkgdelete uninstall_options.flatten.compact.join(' '), @resource[:name]
  end

  def purge
    pkgdelete "-c", "-q", @resource[:name]
  end
end
