test_name 'C70338: ENC could use agent_specified_environment fact' do
  require 'puppet/acceptance/environment_utils'
  extend  Puppet::Acceptance::EnvironmentUtils

  test_name = File.basename(__FILE__, '.*')
  testdir   = create_tmpdir_for_user(master, test_name)
  tmp_environment = mk_tmp_environment_with_teardown(master, test_name)

  sitepp = <<-SITEPP
notify{"ENV${::agent_specified_environment}ENV":}
  SITEPP

  create_sitepp(master, 'production',    sitepp)
  create_sitepp(master, tmp_environment, sitepp)

  teardown do
    # we need to tear this down because it's not in a tmp environment
    on(master, "rm #{environmentpath}/production/manifests/site.pp")
  end

  master_opts = {}

  with_puppet_running_on(master, master_opts, testdir)do
    agents.each do |agent|
      step 'no environment specified' do
        run_agent_on(agent, "-t --server #{master}", :acceptable_exit_codes => 2) do |result|
          assert_match(/: ENVENV/, result.stdout, "The file from environment 'special' was not found")
        end
      end
      step 'environment specified on agent cli' do
        run_agent_on(agent, "-t --server #{master} --environment #{tmp_environment}",
                     :acceptable_exit_codes => 2) do |result|
          assert_match(/: ENV#{tmp_environment}ENV/, result.stdout, "The file from environment 'special' was not found")
        end
      end
    end
  end


  master_opts = {
    'agent' => {
      'environment' => 'nonesuch',
    },
  }
  with_puppet_running_on(master, master_opts, testdir)do
    agents.each do |agent|
      step 'environment specified in puppet.conf and on agent cli' do
        run_agent_on(agent, "-t --server #{master} --environment #{tmp_environment}",
                     :acceptable_exit_codes => 2) do |result|
          assert_match(/: ENV#{tmp_environment}ENV/, result.stdout, "The file from environment 'special' was not found")
        end
      end
    end
  end

end
