test_name "Install puppet gem"

require 'puppet/acceptance/common_utils'

agents.each do |agent|
  sha = ENV['SHA']
  base_url = "http://builds.delivery.puppetlabs.net/puppet/#{sha}/artifacts"

  ruby_command = Puppet::Acceptance::CommandUtils.ruby_command(agent)
  gem_command = Puppet::Acceptance::CommandUtils.gem_command(agent)

  # retrieve the build data, since the gem version is based on the short git
  # describe, not the full git SHA
  on(agent, "curl -s -o build_data.yaml #{base_url}/#{sha}.yaml")
  gem_version = on(agent, "#{ruby_command} -ryaml -e 'puts YAML.load_file(\"build_data.yaml\")[:gemversion]'").stdout.chomp

  if agent['platform'] =~ /windows/
    # wipe existing gems first
    default_dir = on(agent, "#{ruby_command} -rrbconfig -e 'puts Gem.default_dir'").stdout.chomp
    on(agent, "rm -rf '#{default_dir}'")

    arch = agent[:ruby_arch] || 'x86'
    gem_arch = arch == 'x64' ? 'x64-mingw32' : 'x86-mingw32'
    url = "#{base_url}/puppet-#{gem_version}-#{gem_arch}.gem"
  else
    url = "#{base_url}/puppet-#{gem_version}.gem"
  end

  step "Download puppet gem from #{url}"
  on(agent, "curl -s -o puppet.gem #{url}")

  step "Install puppet.gem"
  on(agent, "#{gem_command} install puppet.gem")

  step "Verify it's sane"
  on(agent, puppet('--version'))
  on(agent, puppet('apply', "-e \"notify { 'hello': }\"")) do |result|
    assert_match(/defined 'message' as 'hello'/, result.stdout)
  end
end
