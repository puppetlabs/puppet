require 'puppet/acceptance/common_utils'
require 'puppet/acceptance/install_utils'

extend Puppet::Acceptance::InstallUtils

test_name "Install Packages"

step "Install puppet-agent..." do
  opts = {
    :puppet_collection    => 'PC1',
    :puppet_agent_sha     => ENV['SHA'],
    # SUITE_VERSION is necessary for Beaker to build a package download
    # url which is built upon a `git describe` for a SHA.
    # Beaker currently cannot find or calculate this value based on
    # the SHA, and thus it must be passed at invocation time.
    # The one exception is when SHA is a tag like `1.8.0` and
    # SUITE_VERSION will be equivalent.
    # RE-8333 may make this unnecessary in the future
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
  if ENV['SERVER_VERSION'].nil? || ENV['SERVER_VERSION'] == 'latest'
    server_version = 'latest'
    server_download_url = "http://nightlies.puppet.com"
  else
    server_version = ENV['SERVER_VERSION']
    server_download_url = "http://builds.delivery.puppetlabs.net"
  end
    install_puppetlabs_dev_repo(master, 'puppetserver', server_version, nil, :dev_builds_url => server_download_url)
    install_puppetlabs_dev_repo(master, 'puppet-agent', ENV['SHA'])
    master.install_package('puppetserver')
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
