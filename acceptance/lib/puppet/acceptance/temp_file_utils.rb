module Puppet
  module Acceptance
    module TempFileUtils
      RWXR_XR_X = '0755'
      PUPPET_CODEDIR_PERMISSIONS = RWXR_XR_X

      # Return the name of the root user, as appropriate for the platform.
      def root_user(host)
        case host['platform']
        when /windows/
          'Administrator'
        else
          'root'
        end
      end

      # Return the name of the root group, as appropriate for the platform.
      def root_group(host)
        case host['platform']
        when /windows/
          'Administrators'
        when /aix/
          'system'
        when /osx|bsd/
          'wheel'
        else
          'root'
        end
      end

      # Create a file on the host.
      # Parameters:
      # [host] the host to create the file on
      # [file_path] the path to the file to be created
      # [file_content] a string containing the contents to be written to the file
      # [options] a hash containing additional behavior options.  Currently supported:
      # * :mkdirs (default false) if true, attempt to create the parent directories on the remote host before writing
      #       the file
      # * :owner (default 'root') the username of the user that the file should be owned by
      # * :group (default 'puppet') the name of the group that the file should be owned by
      # * :mode (default '644') the mode (file permissions) that the file should be created with
      def create_test_file(host, file_rel_path, file_content, options = {})

        # set default options
        options[:mkdirs] ||= false
        options[:mode] ||= "755"
        unless options[:owner]
          if host['roles'].include?('master') then
            options[:owner] = host.puppet['user']
          else
            options[:owner] = root_user(host)
          end
        end
        unless options[:group]
          if host['roles'].include?('master') then
            options[:group] = host.puppet['group']
          else
            options[:group] = root_group(host)
          end
        end

        file_path = get_test_file_path(host, file_rel_path)

        mkdirs(host, File.dirname(file_path)) if (options[:mkdirs] == true)
        create_remote_file(host, file_path, file_content)

        #
        # NOTE: we need these chown/chmod calls because the acceptance framework connects to the nodes as "root", but
        #  puppet 'master' runs as user 'puppet'.  Therefore, in order for puppet master to be able to read any files
        #  that we've created, we have to carefully set their permissions
        #

        chown(host, options[:owner], options[:group], file_path)
        chmod(host, options[:mode], file_path)

      end


      # Given a relative path, returns an absolute path for a test file.  Basically, this just prepends the
      # a unique temp dir path (specific to the current test execution) to your relative path.
      def get_test_file_path(host, file_rel_path)
        initialize_temp_dirs unless @host_test_tmp_dirs

        File.join(@host_test_tmp_dirs[host.name], file_rel_path)
      end


      # Check for the existence of a temp file for the current test; basically, this just calls file_exists?(),
      # but prepends the path to the current test's temp dir onto the file_rel_path parameter.  This allows
      # tests to be written using only a relative path to specify file locations, while still taking advantage
      # of automatic temp file cleanup at test completion.
      def test_file_exists?(host, file_rel_path)
        file_exists?(host, get_test_file_path(host, file_rel_path))
      end

      def file_exists?(host, file_path)
        host.execute("test -f \"#{file_path}\"",
                     :acceptable_exit_codes => [0, 1])  do |result|
          return result.exit_code == 0
        end
      end

      def dir_exists?(host, dir_path)
        host.execute("test -d \"#{dir_path}\"",
                     :acceptable_exit_codes => [0, 1])  do |result|
          return result.exit_code == 0
        end
      end

      def link_exists?(host, link_path)
        host.execute("test -L \"#{link_path}\"",
                     :acceptable_exit_codes => [0, 1])  do |result|
          return result.exit_code == 0
        end
      end

      def file_contents(host, file_path)
        host.execute("cat \"#{file_path}\"") do |result|
          return result.stdout
        end
      end

      def tmpdir(host, basename)
        host_tmpdir = host.tmpdir(basename)
        # we need to make sure that the puppet user can traverse this directory...
        chmod(host, "755", host_tmpdir)
        host_tmpdir
      end

      def mkdirs(host, dir_path)
        on(host, "mkdir -p #{dir_path}")
      end

      def chown(host, owner, group, path)
        on(host, "chown #{owner}:#{group} #{path}")
      end

      def chmod(host, mode, path)
        on(host, "chmod #{mode} #{path}")
      end

      # Returns an array containing the owner, group and mode of
      # the file specified by path. The returned mode is an integer
      # value containing only the file mode, excluding the type, e.g
      # S_IFDIR 0040000
      def stat(host, path)
        require File.join(File.dirname(__FILE__),'common_utils.rb')
        ruby = Puppet::Acceptance::CommandUtils.ruby_command(host)
        owner = on(host, "#{ruby} -e 'require \"etc\"; puts (Etc.getpwuid(File.stat(\"#{path}\").uid).name)'").stdout.chomp
        group = on(host, "#{ruby} -e 'require \"etc\"; puts (Etc.getgrgid(File.stat(\"#{path}\").gid).name)'").stdout.chomp
        mode  = on(host, "#{ruby} -e 'puts (File.stat(\"#{path}\").mode & 07777)'").stdout.chomp.to_i

        [owner, group, mode]
      end

      def initialize_temp_dirs()
        # pluck this out of the test case environment; not sure if there is a better way
        @cur_test_file = @path
        @cur_test_file_shortname = File.basename(@cur_test_file, File.extname(@cur_test_file))

        # we need one list of all of the hosts, to assist in managing temp dirs.  It's possible
        # that the master is also an agent, so this will consolidate them into a unique set
        @all_hosts = Set[master, *agents]

        # now we can create a hash of temp dirs--one per host, and unique to this test--without worrying about
        # doing it twice on any individual host
        @host_test_tmp_dirs = Hash[@all_hosts.map do |host| [host.name, tmpdir(host, @cur_test_file_shortname)] end ]
      end

      def remove_temp_dirs()
        @all_hosts.each do |host|
          on(host, "rm -rf #{@host_test_tmp_dirs[host.name]}")
        end
      end

      # a silly variable for keeping track of whether or not all of the tests passed...
      @all_tests_passed = false
    end
  end
end
