test_name "The Exec resource should run commands in the specified cwd" do
  tag 'audit:high',
      'audit:acceptance'

  # Useful utility that converts a string literal
  # to a regex. We do a lot of assertions on file
  # paths here that we need to escape, so this is
  # a nice way of making the code more readable.
  def to_regex(str)
    Regexp.new(Regexp.escape(str))
  end
  
  agents.each do |agent|
    # Calculate some top-level variables we will
    # need for our tests. The mk_tmpdir lambda
    # creates a tmpdir, returning the full
    # platform-specific path of the created
    # subdirectory. The reason we cannot use Beaker's
    # Host#tmpdir is because that returns a Linux path
    # which won't work on Windows.
    unless agent.platform =~ /windows/
      path = '/usr/bin:/usr/sbin:/bin:/sbin'
      print_cwd = 'pwd'

      mk_tmpdir = lambda { agent.tmpdir('exec_cwd_tests') }
    else
      path = 'C:\Windows\System32'
      print_cwd = 'cmd.exe /c echo %CD%'

      mk_tmpdir = lambda do
        # All of our Windows images have Powershell so these
        # calls to Powershell should be safe. Note that
        # '$CYGWINDIR\\tmp' is the /tmp directory on Cygwin. We choose
        # this b/c for some reason, getting it from Powershell places
        # the tmpdir in the C:\Users\Administrator directory, which is not
        # good.
        cygwin_dir = on(agent, 'bash -c "echo $CYGWINDIR"').stdout.chomp.gsub(':', ':\\')
        dir_name = on(
          agent,
          powershell("'[System.IO.Path]::GetRandomFileName()'")
        ).stdout.chomp
        tmp_dir = "#{cygwin_dir}\\tmp\\#{dir_name}"

        on(agent, powershell("mkdir '#{tmp_dir}'"))

        tmp_dir
      end
    end

    pwd = on(agent, print_cwd).stdout.chomp

    # Easier to read than a def. The def. would require us
    # to specify the host as a param. in order to get the path
    # and print_cwd command, which is unnecessary clutter.
    exec_resource_manifest = lambda do |params = {}|
      default_params = {
        :logoutput => true,
        :path      => path,
        :command   => print_cwd
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

    step "Defaults to the PWD if the CWD is not provided" do
      pwd = on(agent, print_cwd).stdout.chomp
      apply_manifest_on(agent, exec_resource_manifest.call) do |result|
        assert_match(to_regex(pwd), result.stdout, 'The Exec resource does not default to using the PWD when the CWD is not provided')
      end
    end

    tmpdir = mk_tmpdir.call      

    step "Runs the command in the specified CWD" do
      apply_manifest_on(agent, exec_resource_manifest.call(cwd: tmpdir)) do |result|
        assert_match(to_regex(tmpdir), result.stdout, 'The Exec resource does not let you specify the CWD')
      end
    end

    step "Errors if the CWD does not exist" do
      cwd = agent.platform =~ /windows/ ? 'C:\nonexistent_dir' : '/nonexistent_dir'
      apply_manifest_on(agent, exec_resource_manifest.call(cwd: cwd)) do |result|
        assert_match(to_regex(cwd), result.stderr, 'The Exec resource does not error when the CWD does not exist!')
      end
    end

    step 'Runs a "check" command (:onlyif or :unless) in the PWD instead of the passed-in CWD' do
      # Idea here is to create a directory (subdir) inside our tmpdir.
      # This will be our CWD. We run our print_cwd command unless
      # subdir exists, which can only happen if our CWD is our tmpdir.
      # Thus, if print_cwd runs successfully, that means our unless
      # check indicated that subdir did not exist, meaning it ran in our
      # pwd instead of our CWD. Note that this is an approximation, but
      # I think it is a good (and simple enough) test to ensure that we
      # enforce this property.
      subdir = 'FOO'
      if agent.platform =~ /windows/
        cwd = "#{tmpdir}\\#{subdir}"
        on(agent, "cmd.exe /c mkdir '#{cwd}'")
        unless_ = "cmd.exe /c dir #{subdir}"
      else
        cwd = "#{tmpdir}/#{subdir}"
        on(agent, "mkdir '#{cwd}'")
        unless_ = "ls #{subdir}"
      end

      manifest = exec_resource_manifest.call(cwd: cwd, unless: unless_)
      apply_manifest_on(agent, manifest) do |result|
        assert_match(to_regex(cwd), result.stdout, 'The Exec resource runs a "check" command in the CWD when it should run it in the PWD instead, only using the CWD for the actual command.')
      end
    end
  end
end
