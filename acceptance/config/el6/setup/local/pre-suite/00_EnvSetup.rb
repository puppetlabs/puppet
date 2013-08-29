test_name "Setup environment"

step "Ensure Git and Ruby"

PACKAGES = {
  /fedora|el|centos/ => [
    'git',
    'ruby',
  ],
  /debian|ubuntu/ => [
    ['git', 'git-core'],
    'ruby',
  ],
  /solaris/ => [
    ['git', 'developer/versioning/git'],
    ['ruby', 'runtime/ruby-18'],
  ],
  /windows/ => [
    'git',
    'ruby',
  ],
}

hosts.each do |host|
  PACKAGES.each do |regex,package_list|
    if regex.match(host['platform'])
      package_list.each do |cmd_pkg|
        if cmd_pkg.kind_of?(Array)
          command, package = cmd_pkg
        else
          command = package = cmd_pkg
        end
        if !host.check_for_package(command)
          step "Installing #{package}"
          host.install_package(package)
        end
      end
    end
  end
end

step "Add Gems"

WINDOWS_GEMS = [
  'sys-admin -v1.5.6', 'win32console -v1.3.2', 'win32-security -v0.1.4', 'win32-dir -v0.3.7', 'win32-eventlog -v0.5.3',
  'win32-process -v0.6.5', 'win32-service -v0.7.2', 'win32-taskscheduler -v0.2.2', 'minitar -v0.5.4'
]

hosts.each do |host|
  case host['platform']
  when /windows/
    WINDOWS_GEMS.each do |gem|
      step "Installing #{gem}"
      on host, "cmd /c gem install #{gem} --no-ri --no-rdoc"
    end
  else
    step "No gems to add"
  end
end

