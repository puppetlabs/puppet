require 'puppet/acceptance/install_utils'

test_name "Install Packages"

step "Install repositories on target machines..." do
  hosts.each do |host|
    platform = host['platform']
    case platform
      when /^(fedora|el|centos)-(\d+)-(.+)$/
        variant = $1
        version = $2
        arch = $3

        on host, "rm -rf /root/*.repo; rm -rf /root/*.rpm"

        rpm = Dir.glob("repo-configs/pl-puppet-dependencies/puppetlabs-release-#{version}-*.rpm").first
        scp_to host, rpm, '/root'

        pattern = "repo-configs/yum-configs/pl-puppet-*-%s-%s%s-%s-*.repo"
        repo = Dir.glob(pattern.%([
          #{variant == 'centos' ? 'el' : variant}
          #{variant == 'fedora' ? 'f' : ''}
          #{version}
          #{arch}
        ])).first
        scp_to host, repo, '/root'

        on hosts, "mv /root/*.repo /etc/yum.repos.d"
        on hosts, "rpm -Uvh --force /root/*.rpm"
      when /^(debian|ubuntu)-([^-]+)-(.+)$/
        variant = $1
        version = $2
        arch = $3

        on host, "rm -rf /root/*.list; rm -rf /root/*.deb"
        scp_to host, "repo-configs/pl-puppet-dependencies/puppetlabs-release-#{version}.deb", '/root'
        list = Dir.glob("repo-configs/yum-configs/pl-puppet-*-#{version}.list").first
        scp_to host, list, '/root'

        on hosts, "mv /root/*.list /etc/apt/sources.list.d"
        on hosts, "dpkg -i --force-all /root/*.deb"
      else
        host.logger.notify("No repository installation step for #{platform} yet...")
    end
  end
end


MASTER_PACKAGES = {
  /fedora|el|centos/ => [
    'puppet-server',
  ],
  /debian|ubuntu/ => [
    'puppet',
  ],
#  /solaris/ => [
#    'puppet-server',
#  ],
#  /windows/ => [
#    'puppet-server',
#  ],
}

AGENT_PACKAGES = {
  /fedora|el|centos/ => [
    'puppet',
  ],
  /debian|ubuntu/ => [
    'puppet',
  ],
#  /solaris/ => [
#    'puppet',
#  ],
#  /windows/ => [
#    'puppet',
#  ],
}

Puppet::Acceptance::InstallUtils.install_packages_on(master, MASTER_PACKAGES)
Puppet::Acceptance::InstallUtils.install_packages_on(agents, AGENT_PACKAGES)
