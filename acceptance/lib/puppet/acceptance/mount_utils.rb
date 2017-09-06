module Puppet
  module Acceptance
    module MountUtils

      # Return the absolute path to the filesystem table file.
      # @param host [String] hostname
      # @return [String] path to the filesystem table file.
      def filesystem_file(host)
        case host['platform']
        when /aix/
          '/etc/filesystems'
        when /el-|centos|fedora|sles|debian|ubuntu|cumulus/
          '/etc/fstab'
        else
          # TODO: Add Solaris and OSX support, as per PUP-5201 and PUP-4823
          fail_test("Unable to determine filesystem table file location for #{host['platform']}")
        end
      end

      # Return a standard filesystem type to use when creating filesysytems.
      # @param host [String] hostname
      # @return [String] filesystem type.
      def filesystem_type(host)
        case host['platform']
        when /aix/
          'jfs2'
        when /el-|centos|fedora|sles|debian|ubuntu|cumulus/
          'ext3'
        else
          # TODO: Add Solaris and OSX support, as per PUP-5201 and PUP-4823
          fail_test("Unable to determine a standard filesystem table type for #{host['platform']}")
        end
      end

      # Appends a new filesystem entry to the filesystem table.
      # @param host [String] hostname.
      # @param mount_name [String] the name of the mount point. We use /tmp/name as the
      # new filesystem, and /name as the actual mount point.
      def add_entry_to_filesystem_table(host, mount_name)
        fs_file = filesystem_file(host)
        fs_type = filesystem_type(host)

        case host['platform']
        when /aix/
          # Note: /dev/hd8 is the default jfs logging device on AIX.
          on(host, "echo '/#{mount_name}:\n  dev = /dev/#{mount_name}\n  vfs = #{fs_type}\n  log = /dev/hd8' >> #{fs_file}")
        when /el-|centos|fedora|sles|debian|ubuntu|cumulus/
          on(host, "echo '/tmp/#{mount_name}  /#{mount_name}  #{fs_type}  loop  0  0' >> #{fs_file}")
        else
          # TODO: Add Solaris and OSX support, as per PUP-5201 and PUP-4823
          fail_test("Adding entries to the filesystem table on #{host['platform']} is not currently supported.")
        end
      end

      # Creates a new filesystem on the host.
      # @param host [String] hostname
      # @param mount_name [String] the name of the mount point.
      def create_filesystem(host, mount_name)
        fs_type = filesystem_type(host)

        case host['platform']
        when /aix/
          volume_group = on(host, 'lsvg').stdout.split("\n")[0]
          on(host, "mklv -y #{mount_name} #{volume_group} 1M")
          on(host, "mkfs -V #{fs_type} -l #{mount_name} /dev/#{mount_name}")
        when /el-|centos|fedora|sles|debian|ubuntu|cumulus/
          on(host, "dd if=/dev/zero of=/tmp/#{mount_name} count=10240", :acceptable_exit_codes => [0,1])
          on(host, "yes | mkfs -t #{fs_type} -q /tmp/#{mount_name}", :acceptable_exit_codes => (0..254))
        else
          # TODO: Add Solaris and OSX support, as per PUP-5201 and PUP-4823
          fail_test("Creating filesystems on #{host['platform']} is not currently supported.")
        end
      end
    end
  end
end
