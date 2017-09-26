require 'puppet/acceptance/common_utils'
require 'puppet/acceptance/install_utils'

extend Puppet::Acceptance::InstallUtils

test_name "Install Packages"

DEFAULT_BUILDS_URL = 'http://builds.delivery.puppetlabs.net'
dev_builds_url = ENV['DEV_BUILDS_URL'] || DEFAULT_BUILDS_URL

step "Install puppet-agent..." do
  hosts.each do |host|
    # An EC2 master instance does not have access to puppetlabs.net for getting
    # dev repos. They are installed during the puppetserver install step.
    next if host == master && master[:hypervisor] == 'ec2'

    if dev_builds_url == DEFAULT_BUILDS_URL
      install_from_build_data_url('puppet-agent', "#{dev_builds_url}/puppet-agent/#{ENV['SHA']}/artifacts/#{ENV['SHA']}.yaml",host)
    else
      install_puppetlabs_dev_repo(host, 'puppet-agent', ENV['SHA'], nil, :dev_builds_url => dev_builds_url)
      host.install_package('puppet-agent')
    end
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
      # Upgrade installed puppet-agent with targeted SHA.
      if dev_builds_url == DEFAULT_BUILDS_URL
        base_url, build_details = fetch_build_details("#{dev_builds_url}/puppet-agent/#{ENV['SHA']}/artifacts/#{ENV['SHA']}.yaml")
        artifact_url, _ = host_urls(master, build_details, base_url)
        release_path = File.dirname(artifact_url)
        release_file = File.basename(artifact_url)
      else
        release_path_end, release_file = master.puppet_agent_dev_package_info( opts[:puppet_collection], opts[:puppet_agent_version], opts)
        release_path = "#{opts[:dev_builds_url]}/puppet-agent/#{opts[:puppet_agent_sha]}/repos/"
        release_path << release_path_end
      end
      copy_dir_local = File.join('tmp', 'repo_configs', master['platform'])
      fetch_http_file(release_path, release_file, copy_dir_local)
      scp_to master, File.join(copy_dir_local, release_file), master.external_copy_base
      on master, "rpm -Uvh #{File.join(master.external_copy_base, release_file)} --oldpackage --force"
    else
      fail_test("EC2 master found, but it was not an `el` host: The specified `puppet-agent` build (#{ENV['SHA']}) cannot be installed.")
    end
  else
    if ENV['SERVER_VERSION'] && ENV['SERVER_VERSION'] != 'latest' && dev_builds_url == DEFAULT_BUILDS_URL
      install_from_build_data_url('puppetserver', "#{dev_builds_url}/puppetserver/#{ENV['SERVER_VERSION']}/artifacts/#{ENV['SERVER_VERSION']}.yaml", master)
    else
      dev_builds_url = 'https://nightlies.puppetlabs.com' if dev_builds_url == DEFAULT_BUILDS_URL
      server_version = ENV['SERVER_VERSION'] || 'latest'
      install_puppetlabs_dev_repo(master, 'puppetserver', server_version, nil, :dev_builds_url => dev_builds_url)
      master.install_package('puppetserver')
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
