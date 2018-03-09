# Plug-in type for handling k5login files
require 'puppet/util'
require 'puppet/util/selinux'
require 'puppet/type/file/selcontext'

Puppet::Type.newtype(:k5login) do
  @doc = "Manage the `.k5login` file for a user.  Specify the full path to
    the `.k5login` file as the name, and an array of principals as the
    `principals` attribute."

  ensurable

  # Principals that should exist in the file
  newproperty(:principals, :array_matching => :all) do
    desc "The principals present in the `.k5login` file. This should be specified as an array."
  end

  # The path/name of the k5login file
  newparam(:path) do
    isnamevar
    desc "The path to the `.k5login` file to manage.  Must be fully qualified."

    validate do |value|
      unless absolute_path?(value)
        raise Puppet::Error, _("File paths must be fully qualified.")
      end
    end
  end

  # To manage the mode of the file
  newproperty(:mode) do
    desc "The desired permissions mode of the `.k5login` file. Defaults to `644`."
    defaultto { "644" }
  end

  # To manage the selinux user of the file
  newproperty(:seluser, :parent => Puppet::SELFileContext) do
    desc "What the SELinux user component of the context of the file should be.
      Any valid SELinux user component is accepted.  For example `user_u`.
      If not specified it defaults to the value returned by matchpathcon for
      the file, if any exists.  Only valid on systems with SELinux support
      enabled."

    defaultto { "user_u" }
  end

  # To manage the selinux role of the file
  newproperty(:selrole, :parent => Puppet::SELFileContext) do
    desc "What the SELinux role component of the context of the file should be.
      Any valid SELinux role component is accepted.  For example `role_r`.
      If not specified it defaults to the value returned by matchpathcon for
      the file, if any exists.  Only valid on systems with SELinux support
      enabled."

    defaultto { "object_r" }
  end

  # To manage the selinux type of the file
  newproperty(:seltype, :parent => Puppet::SELFileContext) do
    desc "What the SELinux type component of the context of the file should be.
      Any valid SELinux type component is accepted.  For example `tmp_t`.
      If not specified it defaults to the value returned by matchpathcon for
      the file, if any exists.  Only valid on systems with SELinux support
      enabled."

    # to my knowledge, `krb5_home_t` is the only valid type for .k5login
    defaultto { "krb5_home_t" }
  end

  # To manage the selinux range of the file
  newproperty(:selrange, :parent => Puppet::SELFileContext) do
    desc "What the SELinux range component of the context of the file should be.
      Any valid SELinux range component is accepted.  For example `s0` or
      `SystemHigh`.  If not specified it defaults to the value returned by
      matchpathcon for the file, if any exists.  Only valid on systems with
      SELinux support enabled and that have support for MCS (Multi-Category
      Security)."

    defaultto { "s0" }
  end

  # Stat our file.
  #
  # We use the initial value :needs_stat to ensure we only stat the file once,
  # but can also keep track of a failed stat (@stat == nil). This also allows
  # us to re-stat on demand by setting @stat = :needs_stat.
  def stat
    return @stat unless @stat == :needs_stat

    @stat = begin
      Puppet::FileSystem.stat(self[:path])
    rescue Errno::ENOENT
      nil
    rescue Errno::ENOTDIR
      nil
    rescue Errno::EACCES
      warning _("Could not stat; permission denied")
      nil
    end
  end

  def initialize(args)
    @stat = :needs_stat
    super
  end

  # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # 

  provide(:k5login) do
    desc "The k5login provider is the only provider for the k5login
      type."

    include Puppet::Util::SELinux

    # Does this file exist?
    def exists?
      Puppet::FileSystem.exist?(@resource[:name])
    end

    # create the file
    def create
      write(@resource.should(:principals))
      should_mode = @resource.should(:mode)
      unless self.mode == should_mode
        self.mode = should_mode
      end
    end

    # remove the file
    def destroy
      Puppet::FileSystem.unlink(@resource[:name])
    end

    # Return the principals
    def principals
      if Puppet::FileSystem.exist?(@resource[:name])
        File.readlines(@resource[:name]).collect { |line| line.chomp }
      else
        :absent
      end
    end

    # Write the principals out to the k5login file
    def principals=(value)
      write(value)
    end

    # Return the mode as an octal string, not as an integer
    def mode
      "%o" % (Puppet::FileSystem.stat(@resource[:name]).mode & 007777)
    end

    # Set the file mode, converting from a string to an integer.
    def mode=(value)
      File.chmod(Integer("0#{value}"), @resource[:name])
    end

    private
    def write(value)
      Puppet::Util.replace_file(@resource[:name], 0644) do |f|
        f.puts value
      end
    end
  end
end
