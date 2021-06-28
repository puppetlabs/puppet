test_name "Be able to execute array commands" do
  tag 'audit:high',
      'audit:acceptance'

  agents.each do |agent|
    if agent.platform =~ /windows/
      cmd = ['C:\Windows\System32\cmd.exe', '/c', 'echo', '*']
    else
      cmd = ['/bin/echo', '*']
    end

    exec_manifest = <<~MANIFEST
      exec { "test exec":
        command => #{cmd},
        logoutput => true,
      }
    MANIFEST

    apply_manifest_on(agent, exec_manifest) do |output|
      assert_match('Notice: /Stage[main]/Main/Exec[test exec]/returns: *', output.stdout)
    end
  end
end
