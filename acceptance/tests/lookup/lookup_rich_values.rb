test_name 'C99044: lookup should allow rich data as values' do
  require 'puppet/acceptance/environment_utils.rb'
  extend Puppet::Acceptance::EnvironmentUtils

tag 'audit:medium',
    'audit:acceptance',
    'audit:refactor',  # Master is not needed for this test. Refactor
                       # to use puppet apply with a local environment.

  # The following two lines are required for the puppetserver service to
  # start correctly. These should be removed when PUP-7102 is resolved.
  confdir = puppet_config(master, 'confdir', section: 'master')
  on(master, "chown puppet:puppet #{confdir}/hiera.yaml")

  app_type        = File.basename(__FILE__, '.*')
  tmp_environment = mk_tmp_environment_with_teardown(master, app_type)
  fq_tmp_environmentpath  = "#{environmentpath}/#{tmp_environment}"

  sensitive_value_rb = 'foot, no mouth'
  sensitive_value_pp = 'toe, no step'
  sensitive_value_pp2 = 'toe, no module'

  step "create ruby lookup function in #{tmp_environment}" do
    on(master, "mkdir -p #{fq_tmp_environmentpath}/lib/puppet/functions/environment")
    create_remote_file(master, "#{fq_tmp_environmentpath}/hiera.yaml", <<-HIERA)
---
version: 5
hierarchy:
  - name: Test
    data_hash: rich_data_test
  - name: Test2
    data_hash: some_mod::rich_data_test2
  - name: Test3
    data_hash: rich_data_test3
  HIERA
    create_remote_file(master, "#{fq_tmp_environmentpath}/lib/puppet/functions/rich_data_test.rb", <<-FUNC)
Puppet::Functions.create_function(:rich_data_test) do
  def rich_data_test(options, context)
    rich_type_instance = Puppet::Pops::Types::PSensitiveType::Sensitive.new("#{sensitive_value_rb}")
    {
      'environment_key' => rich_type_instance,
    }
  end
end
    FUNC
  end

  step "create puppet language lookup function in #{tmp_environment} module" do
    on(master, "mkdir -p #{fq_tmp_environmentpath}/modules/some_mod/functions")
    create_remote_file(master, "#{fq_tmp_environmentpath}/modules/some_mod/functions/rich_data_test2.pp", <<-FUNC)
function some_mod::rich_data_test2($options, $context) {
  {
    "environment_key2" => Sensitive('#{sensitive_value_pp}'),
  }
}
    FUNC
    on(master, "chmod -R a+rw #{fq_tmp_environmentpath}")
  end

  step "C99571: create puppet language lookup function in #{tmp_environment}" do
    on(master, "mkdir -p #{fq_tmp_environmentpath}/functions")
    create_remote_file(master, "#{fq_tmp_environmentpath}/functions/rich_data_test3.pp", <<-FUNC)
function rich_data_test3($options, $context) {
  {
    "environment_key3" => Sensitive('#{sensitive_value_pp2}'),
  }
}
    FUNC
    on(master, "chmod -R a+rw #{fq_tmp_environmentpath}")
  end

  step "create site.pp which calls lookup on our keys" do
    create_sitepp(master, tmp_environment, <<-SITE)
      notify { "${unwrap(lookup('environment_key'))}": }
      notify { "${unwrap(lookup('environment_key2'))}": }
      notify { "${unwrap(lookup('environment_key3'))}": }
    SITE
  end

  step 'assert lookups using lookup subcommand' do
    on(master, puppet('lookup', "--environment #{tmp_environment}", 'environment_key'), :accept_all_exit_codes => true) do |result|
      assert(result.exit_code == 0, "lookup subcommand using ruby function didn't exit properly: (#{result.exit_code})")
      assert_match(sensitive_value_rb, result.stdout,
                   "lookup subcommand using ruby function didn't find correct key")
    end
    on(master, puppet('lookup', "--environment #{tmp_environment}", 'environment_key2'), :accept_all_exit_codes => true) do |result|
      assert(result.exit_code == 0, "lookup subcommand using puppet function in module didn't exit properly: (#{result.exit_code})")
      assert_match(sensitive_value_pp, result.stdout,
                   "lookup subcommand using puppet function in module didn't find correct key")
    end
    on(master, puppet('lookup', "--environment #{tmp_environment}", 'environment_key3'), :accept_all_exit_codes => true) do |result|
      assert(result.exit_code == 0, "lookup subcommand using puppet function didn't exit properly: (#{result.exit_code})")
      assert_match(sensitive_value_pp2, result.stdout,
                   "lookup subcommand using puppet function didn't find correct key")
    end
  end

  with_puppet_running_on(master,{}) do
    agents.each do |agent|
      step "agent lookup in ruby function" do
        on(agent, puppet('agent', "-t --server #{master.hostname} --environment #{tmp_environment}"),
           :accept_all_exit_codes => true) do |result|
          assert(result.exit_code == 2, "agent lookup using ruby function didn't exit properly: (#{result.exit_code})")
          assert_match(sensitive_value_rb, result.stdout,
                       "agent lookup using ruby function didn't find correct key")
          assert_match(sensitive_value_pp, result.stdout,
                       "agent lookup using puppet function in module didn't find correct key")
          assert_match(sensitive_value_pp2, result.stdout,
                       "agent lookup using puppet function didn't find correct key")
        end
      end
    end
  end

end
