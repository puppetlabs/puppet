test_name "Register puppetres.dll on any windows agents" do

  agents.each do |host|
    next unless host['platform'] =~ /windows/
    app_name = 'HKLM\\\\SYSTEM\\\\CurrentControlSet\\\\services\\\\eventlog\\\\Application\\\\Puppet'
    puppetres_dll_cygpath = on(host, "find /cygdrive/c -type f -name puppetres.dll").stdout.chomp
    puppetres_dll = on(host, "cygpath -m \"#{puppetres_dll_cygpath}\"").stdout.chomp
    on host, "REG ADD #{app_name}"
    on host, "REG ADD #{app_name} /v EventMessageFile /t REG_SZ /d '#{puppetres_dll.tr('/', '\\')}'"
    on host, "REG ADD #{app_name} /v TypesSupported /t REG_DWORD /d 7"
  end
end
