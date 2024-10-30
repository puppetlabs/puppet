# frozen_string_literal: true

require_relative '../../../puppet/provider/package'

# Packaging on OpenBSD.  Doesn't work anywhere else that I know of.
Puppet::Type.type(:package).provide :openbsd, :parent => Puppet::Provider::Package do
  desc "OpenBSD's form of `pkg_add` support.

    OpenBSD has the concept of package branches, providing multiple versions of the
    same package, i.e. `stable` vs. `snapshot`. To select a specific branch,
    suffix the package name with % sign follwed by the branch name, i.e. `gimp%stable`.

    This provider supports the `install_options` and `uninstall_options`
    attributes, which allow command-line flags to be passed to pkg_add and pkg_delete.
    These options should be specified as an array where each element is either a
     string or a hash."

  commands :pkgadd => "pkg_add",
           :pkginfo => "pkg_info",
           :pkgdelete => "pkg_delete"

  defaultfor 'os.name' => :openbsd
  confine 'os.name' => :openbsd

  has_feature :install_options
  has_feature :uninstall_options
  has_feature :supports_flavors

  def self.instances
    packages = []

    begin
      execpipe(listcmd) do |process|
        # our regex for matching pkg_info output
        regex = /^(.*)--([\w-]+)?(%[^w]+)?$/
        fields = [:name, :flavor, :branch]
        hash = {}

        # now turn each returned line into a package object
        process.each_line { |line|
          match = regex.match(line.split("\n")[0])
          if match
            fields.zip(match.captures) { |field, value|
              hash[field] = value
            }

            hash[:name] = "#{hash[:name]}#{hash[:branch]}" if hash[:branch]

            hash[:provider] = name
            packages << new(hash)
            hash = {}
          else
            unless line =~ /Updating the pkgdb/
              # Print a warning on lines we can't match, but move
              # on, since it should be non-fatal
              warning(_("Failed to match line %{line}") % { line: line })
            end
          end
        }
      end

      packages
    rescue Puppet::ExecutionFailure
      nil
    end
  end

  def self.listcmd
    [command(:pkginfo), "-a", "-z"]
  end

  def install
    cmd = []

    full_name = get_full_name

    cmd << '-r'
    cmd << install_options
    cmd << full_name

    # pkg_add(1) doesn't set the return value upon failure so we have to peek
    # at it's output to see if something went wrong.
    output = Puppet::Util.withenv({}) { pkgadd cmd.flatten.compact }
    if output =~ /Can't find /
      self.fail "pkg_add returned: #{output.chomp}"
    end
  end

  def get_full_name
    # In case of a real update (i.e., the package already exists) then
    # pkg_add(8) can handle the flavors. However, if we're actually
    # installing with 'latest', we do need to handle the flavors. This is
    # done so we can feed pkg_add(8) the full package name to install to
    # prevent ambiguity.

    name_branch_regex = /^(\S*)(%\w*)$/
    match = name_branch_regex.match(@resource[:name])
    if match
      use_name = match.captures[0]
      use_branch = match.captures[1]
    else
      use_name = @resource[:name]
      use_branch = ''
    end

    if @resource[:flavor]
      "#{use_name}--#{@resource[:flavor]}#{use_branch}"
    else
      "#{use_name}--#{use_branch}"
    end
  end

  def query
    pkg = self.class.instances.find do |package|
      @resource[:name] == package.name
    end
    pkg ? pkg.properties : nil
  end

  def install_options
    join_options(resource[:install_options])
  end

  def uninstall_options
    join_options(resource[:uninstall_options]) || []
  end

  def uninstall
    pkgdelete uninstall_options.flatten.compact, get_full_name
  end

  def purge
    pkgdelete "-c", "-qq", uninstall_options.flatten.compact, get_full_name
  end

  def flavor
    @property_hash[:flavor]
  end

  def flavor=(value)
    if flavor != @resource.should(:flavor)
      install
    end
  end
end
