test_name "Purge and Reinstall Packages" do
  if !ENV['SKIP_PACKAGE_REINSTALL']
    hosts.each do |host|
      host.uninstall_package('puppet')
      host.uninstall_package('puppet-common')
      additional_switches = '--allow-unauthenticated' if host['platform'] =~ /debian|ubuntu/
      host.install_package('puppet', additional_switches)
    end
  end
end
