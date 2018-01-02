test_name "PUP-5274: CA and host private keys should not be world readable" do
  require 'puppet/acceptance/common_utils'

  confine :except, :platform => 'windows'

  tag 'audit:medium',      # low risk of change, high (security) impact if changed
      'audit:refactor',    # Use block style `test_name`
      'audit:integration', # afaict, code creates and manages these files (not packaging)
      'server'             # this code path in Ruby is deprecated...

  def get_setting(host, ssldir, command)
    on(host, puppet("agent --ssldir #{ssldir} #{command}")).stdout.chomp
  end

  def get_mode(host, path)
    ruby = Puppet::Acceptance::CommandUtils.ruby_command(host)
    on(host, "#{ruby} -e 'puts (File.stat(\"#{path}\").mode & 07777).to_s(8)'").stdout.chomp
  end

  hosts.each do |host|
    ssldir        = host.tmpdir('ssldir')
    cakey         = get_setting(host, ssldir, "--configprint cakey")
    privatekeydir = get_setting(host, ssldir, "--configprint privatekeydir")
    hostprivkey   = get_setting(host, ssldir, "--configprint hostprivkey --certname foo")

    step "create ca and foo cert and private keys"
    on(host, puppet("cert generate foo --ssldir #{ssldir}"))

    expected_permissions = {
      cakey         => "640",
      privatekeydir => "750",
      hostprivkey   => "640"
    }

    [cakey, privatekeydir, hostprivkey].each do |path|
      step "verify #{path} has permissions #{expected_permissions[path]} initially"
      current_mode = get_mode(host, path)
      assert_equal(expected_permissions[path], current_mode, "The path #{path} should not be world readable initially")
    end

    step "generate a second cert"
    on(host, puppet("cert generate bar --ssldir #{ssldir}"))

    [cakey, privatekeydir, hostprivkey].each do |path|
      step "verify #{path} still has permissions #{expected_permissions[path]}"
      current_mode = get_mode(host, path)
      assert_equal(expected_permissions[path], current_mode, "The path #{path} should not be changed to world readable")
    end
  end

end
