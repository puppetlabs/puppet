# Plug-in type for handling k5login files
require 'puppet/util'

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
        raise Puppet::Error, "File paths must be fully qualified."
      end
    end
  end

  # To manage the mode of the file
  newproperty(:mode) do
    desc "The desired permissions mode of the `.k5login` file. Defaults to `644`."
    defaultto { "644" }
  end

  provide(:k5login) do
    desc "The k5login provider is the only provider for the k5login
      type."

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
