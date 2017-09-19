require 'puppet/acceptance/common_utils'
require 'puppet/acceptance/install_utils'

extend Puppet::Acceptance::InstallUtils

test_name "Install Packages"

step "Install puppet-agent..." do
  dev_builds_url = ENV['DEV_BUILDS_URL'] || 'http://builds.delivery.puppetlabs.net'
  install_from_build_data_url('puppet-agent', "#{dev_builds_url}/puppet-agent/#{ENV['SHA']}/artifacts/#{ENV['SHA']}.yaml", agents)
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
  if master[:hypervisor] == 'ec2'
    if master[:platform].match(/(?:el|centos|oracle|redhat|scientific)/)
      # An EC2 master instance does not have access to puppetlabs.net for getting
      # dev repos.
      #
      # We will install the appropriate repo to satisfy the puppetserver requirement
      # and then upgrade puppet-agent with the targeted SHA package afterwards.
      #
      # Currently, only an `el` master is supported for this operation.
      if ENV['SERVER_VERSION']
        variant, version = master['platform'].to_array
        if ENV['SERVER_VERSION'].to_i < 5
          logger.info "EC2 master found: Installing nightly build of puppet-agent repo to satisfy puppetserver dependency."
          on(master, "rpm -Uvh https://yum.puppetlabs.com/puppetlabs-release-pc1-el-#{version}.noarch.rpm")
        else
          logger.info "EC2 master found: Installing nightly build of puppet-agent repo to satisfy puppetserver dependency."
          on(master, "rpm -Uvh https://yum.puppetlabs.com/puppet5-release-el-#{version}.noarch.rpm")
        end
      else
        logger.info "EC2 master found: Installing nightly build of puppet-agent repo to satisfy puppetserver dependency."
        install_repos_on(master, 'puppet-agent', 'nightly', 'repo-configs')
        install_repos_on(master, 'puppetserver', 'nightly', 'repo-configs')
      end

      master.install_package('puppetserver')

      logger.info "EC2 master found: Installing #{ENV['SHA']} build of puppet-agent."
      dev_builds_url = ENV['DEV_BUILDS_URL'] || 'http://builds.delivery.puppetlabs.net'
      install_from_build_data_url('puppet-agent', "#{dev_builds_url}/puppet-agent/#{ENV['SHA']}/artifacts/#{ENV['SHA']}.yaml", master)
    else
      fail_test("EC2 master found, but it was not an `el` host: The specified `puppet-agent` build (#{ENV['SHA']}) cannot be installed.")
    end
  else
    dev_builds_url = ENV['DEV_BUILDS_URL'] || "http://builds.delivery.puppetlabs.net"
    install_from_build_data_url('puppet-agent', "#{dev_builds_url}/puppet-agent/#{ENV['SHA']}/artifacts/#{ENV['SHA']}.yaml", master)
    if ENV['SERVER_VERSION'].nil? || ENV['SERVER_VERSION'] == 'latest'
      install_puppetlabs_dev_repo(master, 'puppetserver', 'latest', nil, :dev_builds_url => 'http://nightlies.puppet.com')
      master.install_package('puppetserver')
    else
      install_from_build_data_url('puppetserver', "#{dev_builds_url}/puppetserver/#{ENV['SERVER_VERSION']}/artifacts/#{ENV['SERVER_VERSION']}.yaml", master)
    end
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
