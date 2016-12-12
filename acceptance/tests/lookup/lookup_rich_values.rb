test_name 'C99044 lookup should allow rich data as values' do
  require 'puppet/acceptance/puppet_type_test_tools.rb'
  extend Puppet::Acceptance::PuppetTypeTestTools

  app_type        = File.basename(__FILE__, '.*')
  tmp_environment = mk_tmp_environment_with_teardown(master, app_type)
  fq_tmp_environmentpath  = "#{environmentpath}/#{tmp_environment}"
  tmp_environment2 = mk_tmp_environment_with_teardown(master, app_type)
  fq_tmp_environmentpath2  = "#{environmentpath}/#{tmp_environment2}"

  sensitive_value_rb = 'foot, no mouth'
  sensitive_value_pp = 'toe, no step'


  step "create ruby lookup function in #{tmp_environment}" do
    on(master, "mkdir -p #{fq_tmp_environmentpath}/lib/puppet/functions/environment")
    create_remote_file(master, "#{fq_tmp_environmentpath}/hiera.yaml", <<-HIERA)
---
version: 5
hierarchy:
  - name: Test
    data_hash: rich_data_test
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
    create_sitepp(master, tmp_environment, <<-SITE)
      notify { "${unwrap(lookup('environment_key'))}": }
    SITE
    on(master, "chmod -R a+rw #{fq_tmp_environmentpath}")
  end

  step "create puppet lookup function in #{tmp_environment2}" do
    on(master, "mkdir -p #{fq_tmp_environmentpath2}/functions #{fq_tmp_environmentpath2}/modules/some_mod/functions")
    create_remote_file(master, "#{fq_tmp_environmentpath2}/hiera.yaml", <<-HIERA)
---
version: 5
hierarchy:
  - name: Test
    data_hash: some_mod::rich_data_test
  HIERA
    create_remote_file(master, "#{fq_tmp_environmentpath2}/modules/some_mod/functions/rich_data_test.pp", <<-FUNC)
function some_mod::rich_data_test($options, $context) {
  {
    "environment_key" => Sensitive('#{sensitive_value_pp}'),
  }
}
    FUNC
    create_sitepp(master, tmp_environment2, <<-SITE)
      notify { "${unwrap(lookup('environment_key'))}": }
    SITE
    on(master, "chmod -R a+rw #{fq_tmp_environmentpath2}")
  end
  #TODO: put the functions in modules as well

  step 'assert lookups using lookup subcommand' do
    on(master, puppet('lookup', "--environment #{tmp_environment}", 'environment_key'), :accept_all_exit_codes => true) do |result|
      assert(result.exit_code == 0, "lookup subcommand using ruby function didn't exit properly: (#{result.exit_code})")
      assert_match(sensitive_value_rb, result.stdout,
                   "lookup subcommand using ruby function didn't find correct key")
    end
    on(master, puppet('lookup', "--environment #{tmp_environment2}", 'environment_key'), :accept_all_exit_codes => true) do |result|
      assert(result.exit_code == 0, "lookup subcommand using puppet function didn't exit properly: (#{result.exit_code})")
      assert_match(sensitive_value_pp, result.stdout,
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
        end
      end
      step "agent lookup in puppet function" do
        on(agent, puppet('agent', "-t  --server #{master.hostname} --environment #{tmp_environment2}"),
           :accept_all_exit_codes => true) do |result|
          assert(result.exit_code == 2, "agent lookup using puppet function didn't exit properly: (#{result.exit_code})")
          assert_match(sensitive_value_pp, result.stdout,
                       "agent lookup using puppet function didn't find correct key")
        end
      end
    end
  end

end
