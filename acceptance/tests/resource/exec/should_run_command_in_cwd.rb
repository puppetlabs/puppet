test_name "The Exec resource should run commands in the specified cwd" do
  tag 'audit:high',
      'audit:acceptance'
  confine :except, :platform => /debian-12-amd64/ # PUP-12020

  require 'puppet/acceptance/windows_utils'
  extend Puppet::Acceptance::WindowsUtils

  # Useful utility that converts a string literal
  # to a regex. We do a lot of assertions on file
  # paths here that we need to escape, so this is
  # a nice way of making the code more readable.
  def to_regex(str)
    Regexp.new(Regexp.escape(str))
  end

  def exec_resource_manifest(command, params = {})
    default_params = {
      :command   => command
    }
    params = default_params.merge(params)

    params_str = params.map do |param, value|
      value_str = value.to_s
      # Single quote the strings in case our value is a Windows
      # path
      value_str = "'#{value_str}'" if value.is_a?(String)

      "  #{param} => #{value_str}"
    end.join(",\n")

    <<-MANIFEST
  exec { 'run_test_command':
  #{params_str}
  }
  MANIFEST
  end

  def assert_file_on(host, filepath, failure_comment)
    if host.platform =~ /windows/
      cmd = "cmd.exe /c \"type #{filepath.gsub('/', '\\')}\""
    else
      cmd = "test -f #{filepath}"
    end
    on(host, cmd, :acceptable_exit_codes => [0, 1]) do |result|
      assert_equal(0, result.exit_code, failure_comment)
    end
  end

  agents.each do |agent|
    testdir = agent.tmpdir("mock_testdir")
    if agent.platform =~ /windows/
      path = 'C:\Windows\System32'
      echo_to = 'cmd.exe /c echo testing >'
      cat = 'cmd.exe /c type'
      non_existant_dir = 'C:\does_not_exist'
      origin_working_dir = on(agent, 'cmd.exe /c echo %CD%').stdout.chomp
    else
      path = '/usr/bin:/usr/sbin:/bin:/sbin'
      echo_to = 'echo testing >'
      cat = 'cat'
      non_existant_dir = '/does_not_exist'
      origin_working_dir = on(agent, 'pwd').stdout.chomp
    end

    step "clean current working directory" do
      on(agent, "rm -f cwd_test*")
    end

    step "Defaults to the current directory if the CWD option is not provided" do
      apply_manifest_on(agent, exec_resource_manifest("#{echo_to} cwd_test1", {:path => path}), :catch_failures => true)
      assert_file_on(agent, File.join(origin_working_dir, 'cwd_test1'), 'Exec did not create file in origin pwd, exec resource not defaulting to pwd when no :cwd option is given')
    end

    step "Runs the command in the user specified CWD" do
      apply_manifest_on(agent, exec_resource_manifest("#{echo_to} cwd_test2", {:cwd => testdir, :path => path}), :catch_failures => true)
      assert_file_on(agent, File.join(testdir, 'cwd_test2'), 'Exec did not create file in test directory, exec resource not using :cwd given')
    end

    step "Errors if the user specified CWD does not exist" do
      apply_manifest_on(agent, exec_resource_manifest("#{echo_to} cwd_test3", {cwd: non_existant_dir, :path => path}), :expect_failures => true) do |result|
        assert_equal(4, result.exit_code, "Exec manifest still executed with non-existant :cwd")
      end
    end

    # "onlyif" testing will require some form of runnable test in the testdir for the
    # onlyif clause to actually execute. The runnable test we will use is attempting to
    # 'cat' an unqualified file that will only exist in the testdir
    create_remote_file(agent, File.join(testdir, 'testdir_onlyif.txt'), 'testing')

    step 'Runs a "check" command (:onlyif or :unless) in the user specified CWD' do
      apply_manifest_on(agent, exec_resource_manifest("#{echo_to} cwd_test4", {cwd: testdir, :path => path, :onlyif => "#{cat} testdir_onlyif.txt"}), :expect_changes => true)
      assert_file_on(agent, File.join(testdir, 'cwd_test4'), 'Exec did not create file in test directory, exec resource not using :cwd given')
    end

    step 'Does not run the exec if the "check" command (:onlyif or :unless) fails' do
      apply_manifest_on(agent, exec_resource_manifest("#{echo_to} cwd_test5", {cwd: testdir, :path => path, :onlyif => "foobar"}), :expect_failures => true) do |result|
        assert_equal(4, result.exit_code, "Exec manifest still executed with failed :onlyif clause")
      end
    end

    tmpdir_noaccess = agent.tmpdir("mock_dir")
    create_remote_file(agent, File.join(tmpdir_noaccess, 'noaccess.txt'), 'foobar')
    username = "pl#{rand(999999).to_i}"

    # The next two steps set up to test running with a CWD that the user does not have access to.
    # The setup for the test creates 1. a new user and 2. a new directory that the new user does
    # not have access to.
    step "Setup user for 'no access' test" do
      agent.user_present(username)
      if agent.platform =~ /solaris/
        # for some reason applications of 'user_present' on solaris 10 don't manage the homedir correctly, so just
        # force a puppet apply to manage the user
        on agent, puppet_resource('user', username, "ensure=present managehome=true home=/export/home/#{username}")
        # we need to create the user directory ourselves in order for solaris users to successfully login
        on(agent, "mkdir /export/home/#{username} && chown -R #{username} /export/home/#{username}")
      elsif agent.platform =~ /osx/
        # we need to create the user directory ourselves in order for macos users to successfully login
        on(agent, "mkdir /Users/#{username} && chown -R #{username}:80 /Users/#{username}")
      elsif agent.platform =~ /debian|ubuntu|sles/
        # we need to create the user directory ourselves in order for deb users to successfully login
        on(agent, "mkdir /home/#{username} && chown -R #{username} /home/#{username}")
      end
      teardown { agent.user_absent(username) }
    end

    tmpdir_noaccess = agent.tmpdir("mock_noaccess")
    create_remote_file(agent, File.join(tmpdir_noaccess, 'noaccess.txt'), 'foobar')

    step "Setup restricted access directory for 'no access' test" do
      if agent.platform =~ /windows/
        deny_administrator_access_to(agent, tmpdir_noaccess)
        deny_administrator_access_to(agent, File.join(tmpdir_noaccess, 'noaccess.txt'))
      else
        if agent.platform =~ /osx/
          # This is a little nuts, but on MacOS the tmpdir returned from agent.tmpdir is located in
          # a directory that users other than root can't even access, i.e. other users won't have access
          # to either the noaccess dir itself (which we want) _or the tmpdir root it's located in_. This is
          # a problem since it will look to puppet like the noacceess dir doesn't exist at all, and so we
          # can't count on any reliaable failure since we want a return indicating no access, not a missing directory.
          #
          # To get around this for MacOS platforms we simply use the new user's homedir as the 'tmpdir' and
          # put the noaccess dir there.
          on(agent, "mkdir /Users/#{username}/noaccess_test && cp #{tmpdir_noaccess}/noaccess.txt /Users/#{username}/noaccess_test && chmod -R 600 /Users/#{username}/noaccess_test")
          tmpdir_noaccess = "/Users/#{username}/noaccess_test"
        end
        # remove permissions for all other users other than root, which should force puppet to fail when running as another user
        on(agent, "chmod -R 600 #{tmpdir_noaccess}")
      end
    end

    step "Errors if the user does not have access to the specified CWD" do
      manifest_path = agent.tmpfile('apply_manifest.pp')
      create_remote_file(agent, manifest_path, exec_resource_manifest("#{cat} noaccess.txt", {:cwd => tmpdir_noaccess, :path => path}))
      if agent.platform =~ /windows/
        on(agent, "cmd.exe /c \"puppet apply #{manifest_path} --detailed-exitcodes\"", :acceptable_exit_codes => [4]) do |result|
          assert_equal(4, result.exit_code, "Exec manifest still executed inside restricted directory", )
        end
      elsif agent.platform =~ /osx/
        # on MacOS we need to copy the manifest to run to the user's home dir and give the user ownership. otherwise puppet won't run on it.
        on(agent, "cp #{manifest_path} /Users/#{username}/noaccess_manifest.pp && chown #{username}:80 /Users/#{username}/noaccess_manifest.pp")
        on(agent, "su - #{username} -c \"/opt/puppetlabs/bin/puppet apply /Users/#{username}/noaccess_manifest.pp --detailed-exitcodes\"", :acceptable_exit_codes => [4]) do |result|
          assert_equal(4, result.exit_code, "Exec manifest still executed inside restricted directory")
        end
      else
        on(agent, "chown #{username} #{manifest_path}")
        if agent.platform =~ /solaris|aix/
          on(agent, "su - #{username} -c \"/opt/puppetlabs/bin/puppet apply #{manifest_path} --detailed-exitcodes\"", :acceptable_exit_codes => [4]) do |result|
            assert_equal(4, result.exit_code, "Exec manifest still executed inside restricted directory")
          end
        else
          on(agent, "su #{username} -c \"/opt/puppetlabs/bin/puppet apply #{manifest_path} --detailed-exitcodes\"", :acceptable_exit_codes => [4]) do |result|
            assert_equal(4, result.exit_code, "Exec manifest still executed inside restricted directory")
          end
        end
      end
    end
  end
end
