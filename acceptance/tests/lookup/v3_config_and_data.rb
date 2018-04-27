test_name 'C99629: hiera v5 can use v3 config and data' do
  require 'puppet/acceptance/environment_utils.rb'
  extend Puppet::Acceptance::EnvironmentUtils

tag 'audit:medium',
    'audit:acceptance',
    'audit:refactor',  # Master is not needed for this test. Refactor
                       # to use puppet apply with a local module tree.

  app_type        = File.basename(__FILE__, '.*')
  tmp_environment = mk_tmp_environment_with_teardown(master, app_type)
  fq_tmp_environmentpath  = "#{environmentpath}/#{tmp_environment}"

  hiera_conf_backup = master.tmpfile('C99629-hiera-yaml')

  step "create hiera v3 global config and data" do
    confdir = puppet_config(master, 'confdir', section: 'master')

    step "backup global hiera.yaml" do
      on(master, "cp -a #{confdir}/hiera.yaml #{hiera_conf_backup}", :acceptable_exit_codes => [0,1])
    end

    teardown do
      step "restore global hiera.yaml" do
        on(master, "mv #{hiera_conf_backup} #{confdir}/hiera.yaml", :acceptable_exit_codes => [0,1])
      end
    end

    step "create global hiera.yaml and module data" do
      create_remote_file(master, "#{confdir}/hiera.yaml", <<-HIERA)
---
:backends:
  - "yaml"
  - "json"
  - "hocon"
:hierarchy:
  - "somesuch"
  - "common"
      HIERA

      on(master, "mkdir -p #{fq_tmp_environmentpath}/hieradata/")
      create_remote_file(master, "#{fq_tmp_environmentpath}/hieradata/somesuch.yaml", <<-YAML)
---
environment_key1: "env value1"
environment_key3: "env value3"
      YAML
      create_remote_file(master, "#{fq_tmp_environmentpath}/hieradata/somesuch.json", <<-JSON)
{
  "environment_key1" : "wrong value",
  "environment_key2" : "env value2"
}
      JSON
      step "C99628: add hocon backend and data" do
        create_remote_file(master, "#{fq_tmp_environmentpath}/hieradata/somesuch.conf", <<-HOCON)
environment_key4 = "hocon value",
        HOCON
      end

      create_sitepp(master, tmp_environment, <<-SITE)
notify { "${lookup('environment_key1')}": }
notify { "${lookup('environment_key2')}": }
notify { "${lookup('environment_key3')}": }
notify { "${lookup('environment_key4')}": }
      SITE

      on(master, "chmod -R 775 #{fq_tmp_environmentpath}")
      on(master, "chmod -R 775 #{confdir}")
    end
  end

  step 'assert lookups using lookup subcommand' do
    step 'assert lookup --explain using lookup subcommand' do
      on(master, puppet('lookup', "--environment #{tmp_environment}", 'environment_key1 --explain'), :accept_all_exit_codes => true) do |result|
        assert(result.exit_code == 0, "1: lookup subcommand didn't exit properly: (#{result.exit_code})")
        assert_match(/env value1/, result.stdout,
                     "1: lookup subcommand didn't find correct key")
        assert_match(/hiera configuration version 3/, result.stdout,
                     "hiera config version not reported properly")
        assert_match(/#{fq_tmp_environmentpath}\/hieradata\/somesuch\.yaml/, result.stdout,
                     "hiera hierarchy abs path not reported properly")
        assert_match(/path: "somesuch"/, result.stdout,
                     "hiera hierarchy path not reported properly")
      end
    end
    on(master, puppet('lookup', "--environment #{tmp_environment}", 'environment_key2'), :accept_all_exit_codes => true) do |result|
      assert(result.exit_code == 0, "2: lookup subcommand didn't exit properly: (#{result.exit_code})")
      assert_match(/env value2/, result.stdout,
                   "2: lookup subcommand didn't find correct key")
    end
    on(master, puppet('lookup', "--environment #{tmp_environment}", 'environment_key3'), :accept_all_exit_codes => true) do |result|
      assert(result.exit_code == 0, "3: lookup subcommand didn't exit properly: (#{result.exit_code})")
      assert_match(/env value3/, result.stdout,
                   "3: lookup subcommand didn't find correct key")
    end
    on(master, puppet('lookup', "--environment #{tmp_environment}", 'environment_key4'), :accept_all_exit_codes => true) do |result|
      assert(result.exit_code == 0, "4: lookup subcommand didn't exit properly: (#{result.exit_code})")
      assert_match(/hocon value/, result.stdout,
                   "4: lookup subcommand didn't find correct key")
    end
  end

  with_puppet_running_on(master,{}) do
    agents.each do |agent|
      step "agent lookup" do
        on(agent, puppet('agent', "-t --server #{master.hostname} --environment #{tmp_environment}"),
           :accept_all_exit_codes => true) do |result|
          assert(result.exit_code == 2, "agent lookup didn't exit properly: (#{result.exit_code})")
          assert_match(/env value1/, result.stdout,
                       "1: agent lookup didn't find correct key")
          assert_match(/env value2/, result.stdout,
                       "2: agent lookup didn't find correct key")
          assert_match(/env value3/, result.stdout,
                       "3: agent lookup didn't find correct key")
          assert_match(/hocon value/, result.stdout,
                       "4: agent lookup didn't find correct key")
        end
      end
    end
  end
end
