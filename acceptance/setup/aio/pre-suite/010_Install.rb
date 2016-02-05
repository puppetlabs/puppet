require 'puppet/acceptance/common_utils'
require 'puppet/acceptance/install_utils'

extend Puppet::Acceptance::InstallUtils

test_name "Install Packages"

step "Install puppet-agent..." do
  opts = {
    :puppet_collection    => 'PC1',
    :puppet_agent_sha     => ENV['SHA'],
    :puppet_agent_version => ENV['SUITE_VERSION'] || ENV['SHA']
  }
  agents.each do |agent|
    next if agent == master # Avoid SERVER-528
    install_puppet_agent_dev_repo_on(agent, opts)
  end
end

MASTER_PACKAGES = {
  :redhat => [
    'puppetserver',
  ],
  :debian => [
    'puppetserver',
  ],
}

step "Install puppetserver..." do
  if ENV['SERVER_VERSION']
    install_puppetlabs_dev_repo(master, 'puppetserver', ENV['SERVER_VERSION'])
    install_puppetlabs_dev_repo(master, 'puppet-agent', ENV['SHA'])
    master.install_package('puppetserver')
  else
    # beaker can't install puppetserver from nightlies (BKR-673)
    repo_configs_dir = 'repo-configs'
    install_repos_on(master, 'puppetserver', 'nightly', repo_configs_dir)
    install_repos_on(master, 'puppet-agent', ENV['SHA'], repo_configs_dir)
    install_packages_on(master, MASTER_PACKAGES)
  end
end

# make sure install is sane, beaker has already added puppet and ruby
# to PATH in ~/.ssh/environment
agents.each do |agent|
  on agent, puppet('--version')
  ruby = Puppet::Acceptance::CommandUtils.ruby_command(agent)
  on agent, "#{ruby} --version"
end

# Get a rough estimate of clock skew among hosts
times = []
hosts.each do |host|
  ruby = Puppet::Acceptance::CommandUtils.ruby_command(host)
  on(host, "#{ruby} -e 'puts Time.now.strftime(\"%Y-%m-%d %T.%L %z\")'") do |result|
    times << result.stdout.chomp
  end
end
times.map! do |time|
  (Time.strptime(time, "%Y-%m-%d %T.%L %z").to_f * 1000.0).to_i
end
diff = times.max - times.min
if diff < 60000
  logger.info "Host times vary #{diff} ms"
else
  logger.warn "Host times vary #{diff} ms, tests may fail"
end

configure_gem_mirror(hosts)
