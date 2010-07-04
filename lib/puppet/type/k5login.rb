# $Id: k5login.rb 2468 2007-08-07 23:30:20Z digant $
#
# Plug-in type for handling k5login files

Puppet::Type.newtype(:k5login) do
    @doc = "Manage the .k5login file for a user.  Specify the full path to
        the .k5login file as the name and an array of principals as the
        property principals."

    ensurable

    # Principals that should exist in the file
    newproperty(:principals, :array_matching => :all) do
        desc "The principals present in the .k5login file."
    end

    # The path/name of the k5login file
    newparam(:path) do
        isnamevar
        desc "The path to the file to manage.  Must be fully qualified."

        validate do |value|
            unless value =~ /^#{File::SEPARATOR}/
                raise Puppet::Error, "File paths must be fully qualified"
            end
        end
    end

    # To manage the mode of the file
    newproperty(:mode) do
        desc "Manage the k5login file's mode"
        defaultto { "644" }
    end

    provide(:k5login) do
        desc "The k5login provider is the only provider for the k5login
            type."

        # Does this file exist?
        def exists?
            File.exists?(@resource[:name])
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
            File.unlink(@resource[:name])
        end

        # Return the principals
        def principals(dummy_argument=:work_arround_for_ruby_GC_bug)
            if File.exists?(@resource[:name])
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
            "%o" % (File.stat(@resource[:name]).mode & 007777)
        end

        # Set the file mode, converting from a string to an integer.
        def mode=(value)
            File.chmod(Integer("0" + value), @resource[:name])
        end

        private
        def write(value)
            File.open(@resource[:name], "w") { |f| f.puts value.join("\n") }
        end
    end
end
