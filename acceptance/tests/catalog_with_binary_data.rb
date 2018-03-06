test_name "C100300: Catalog containing binary data is applied correctly" do
  skip_test 'requires a master for serving module content' if master.nil?

  require 'puppet/acceptance/common_utils'
  require 'puppet/acceptance/environment_utils'
  extend Puppet::Acceptance::EnvironmentUtils

  require 'puppet/acceptance/agent_fqdn_utils'
  extend Puppet::Acceptance::AgentFqdnUtils

  tag 'risk:medium'

  test_num        = 'c100300'
  tmp_environment = mk_tmp_environment_with_teardown(master, File.basename(__FILE__, '.*'))
  agent_tmp_dirs  = {}
  agents.each do |agent|
    agent_tmp_dirs[agent_to_fqdn(agent)] = agent.tmpdir(tmp_environment)
  end

  teardown do
    step 'remove all test files on agents' do
      agents.each {|agent| on(agent, "rm -r '#{agent_tmp_dirs[agent_to_fqdn(agent)]}'", :accept_all_exit_codes => true)}
    end
    # note - master teardown is registered by #mk_tmp_environment_with_teardown
  end

  step "Create module with binary data file on master" do
    on(master, "mkdir -p '#{environmentpath}/#{tmp_environment}/modules/#{test_num}'/{manifests,files}")
    master_module_manifest    = "#{environmentpath}/#{tmp_environment}/modules/#{test_num}/manifests/init.pp"
    master_module_binary_file = "#{environmentpath}/#{tmp_environment}/modules/#{test_num}/files/binary_data"

    create_remote_file(master, master_module_binary_file, "\xC0\xFF")
    on(master, "chmod 644 '#{master_module_binary_file}'")

    manifest = <<-MANIFEST
      class #{test_num}(
      ) {
        \$test_path = \$::fqdn ? #{agent_tmp_dirs}
        file { '#{test_num}':
          path   => "\$test_path/#{test_num}",
          content => file('#{test_num}/binary_data'),
          ensure => present,
        }
      }
    MANIFEST
    create_remote_file(master, master_module_manifest, manifest)
    on(master, "chmod 644 '#{master_module_manifest}'")
  end

  step "Create site.pp to classify nodes to include module" do
    site_pp_file = "#{environmentpath}/#{tmp_environment}/manifests/site.pp"
    site_pp      = <<-SITE_PP
      node default {
        include #{test_num}
      }
    SITE_PP
    create_remote_file(master, site_pp_file, site_pp)
    on(master, "chmod 644 '#{site_pp_file}'")
  end

  step "start the master" do
    with_puppet_running_on(master, {}) do

      step "run puppet and ensure that binary data was correctly applied" do
        agents.each do |agent|
          on(agent, puppet('agent', '--test', "--environment '#{tmp_environment}'", "--server #{master.hostname}"), :acceptable_exit_codes => 2)
          on(agent, "#{Puppet::Acceptance::CommandUtils::ruby_command(agent)} -e 'puts File.binread(\"#{agent_tmp_dirs[agent_to_fqdn(agent)]}/#{test_num}\").bytes.map {|b| b.to_s(16)}'") do |res|
            assert_match(/c0\nff/, res.stdout, 'Binary file did not contain originally specified data')
          end
        end
      end

    end
  end

end
