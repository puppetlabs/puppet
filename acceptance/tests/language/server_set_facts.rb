test_name 'C64667: ensure server_facts is set and error if any value is overwritten by an agent' do
  require 'puppet/acceptance/environment_utils.rb'
  extend Puppet::Acceptance::EnvironmentUtils

tag 'audit:medium',
    'audit:acceptance', # Validating server/client interaction
    'server'

  app_type        = File.basename(__FILE__, '.*')
  tmp_environment = mk_tmp_environment_with_teardown(master, app_type)
  fq_tmp_environmentpath  = "#{environmentpath}/#{tmp_environment}"

  step 'ensure $server_facts exist' do
    create_sitepp(master, tmp_environment, <<-SITE)
      notify{"abc$server_facts":}
    SITE

    master_opts = {}
    with_puppet_running_on(master, master_opts) do
      agents.each do |agent|
        on(agent, puppet("agent -t --server #{master} --environment #{tmp_environment}"),
           :acceptable_exit_codes => 2) do |result|
          assert_match(/abc{serverversion/, result.stdout,
                       "#{agent}: $server_facts should have some stuff" )
        end
      end
    end
  end

  step 'ensure puppet issues a warning if an agent overwrites a server fact' do
    agents.each do |agent|
      on(agent, puppet("agent -t --server #{master}",
                       'ENV' => { 'FACTER_server_facts' => 'overwrite' }),
        :acceptable_exit_codes => 1) do |result|
          # Do not perform this check on non-English hosts
          unless agent['locale'] == 'ja'
            assert_match(/Error.*Attempt to assign to a reserved variable name: 'server_facts'/,
                         result.stderr, "#{agent}: $server_facts should error if overwritten" )
          end
      end
    end
  end
end
