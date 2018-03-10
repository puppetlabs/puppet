test_name 'C98115 compilation should get new values in variables on each compilation' do
  require 'puppet/acceptance/environment_utils'
  extend Puppet::Acceptance::EnvironmentUtils

  tag 'audit:medium',
      'audit:integration',
      'server'

  app_type               = File.basename(__FILE__, '.*')
  tmp_environment        = mk_tmp_environment_with_teardown(master, app_type)
  fq_tmp_environmentpath = "#{environmentpath}/#{tmp_environment}"

  create_remote_file(master, "#{fq_tmp_environmentpath}/environment.conf", <<-CONF)
    environment_timeout = unlimited
  CONF
  # the module function loading logic is different from inside a single manifest
  #   we exercise both here
  on(master, "mkdir -p '#{fq_tmp_environmentpath}'/modules/custom_time/{manifests,functions,facts.d}")
  create_remote_file(master, "#{fq_tmp_environmentpath}/modules/custom_time/manifests/init.pp", <<-FILE)
    class custom_time {
      $t = custom_time::my_system_time()

      notify { 'custom time':
        message => "module_${t}_module",
      }
    }
  FILE
  create_remote_file(master, "#{fq_tmp_environmentpath}/modules/custom_time/functions/my_system_time.pp", <<-FILE)
    function custom_time::my_system_time() {
      $facts['custom_time']
    }
  FILE
  create_sitepp(master, tmp_environment, <<-SITE)
    function bar() {
      $facts['custom_time']
    }
    class foo::bar {
      notify { "local_${bar()}_local": }
    }
    include foo::bar
    include custom_time
  SITE
  create_remote_file(master, "#{fq_tmp_environmentpath}/modules/custom_time/facts.d/custom_time.sh", <<-FILE)
#!/bin/bash

echo -n "custom_time=$(date +%s%N)"
  FILE

  on(master, "chmod -R 0777 '#{fq_tmp_environmentpath}/'")

  windows_fact_location = "#{fq_tmp_environmentpath}/modules/custom_time/facts.d/custom_time.ps1"
  create_remote_file(master, windows_fact_location, <<-FILE)
echo "custom_time=$(get-date -format HHmmssffffff)"
  FILE

  on(master, "chmod -R 0666 '#{windows_fact_location}'")


  step "run agent in #{tmp_environment}, ensure it increments the customtime with each run" do
    with_puppet_running_on(master, {}) do
      local_custom_time_pattern  = 'local_(\d+)_local'
      module_custom_time_pattern = 'module_(\d+)_module'
      agents.each do |agent|
        # ensure our custom facts have been synced
        on(agent,
           puppet("agent -t --server #{master.hostname} --environment '#{tmp_environment}'"),
           :accept_all_exit_codes => true)

        local_custom_time1 = module_custom_time1 = nil
        local_custom_time2 = module_custom_time2 = nil

        on(agent, puppet("agent -t --server #{master.hostname} --environment '#{tmp_environment}'"),
           :accept_all_exit_codes => [2]) do |result|
          assert_match(/Notice: #{local_custom_time_pattern}/, result.stdout, 'first custom time was not as expected')
          assert_match(/Notice: #{module_custom_time_pattern}/, result.stdout, 'first module uptime was not as expected')

          local_custom_time1  = result.stdout.match(/Notice: #{local_custom_time_pattern}/)[1].to_i
          module_custom_time1 = result.stdout.match(/Notice: #{module_custom_time_pattern}/)[1].to_i
        end

        sleep 1

        on(agent, puppet("agent -t --server #{master.hostname} --environment '#{tmp_environment}'"),
           :accept_all_exit_codes => [2]) do |result|
          assert_match(/Notice: #{local_custom_time_pattern}/, result.stdout, 'second custom time was not as expected')
          assert_match(/Notice: #{module_custom_time_pattern}/, result.stdout, 'second module uptime was not as expected')

          local_custom_time2  = result.stdout.match(/Notice: #{local_custom_time_pattern}/)[1].to_i
          module_custom_time2 = result.stdout.match(/Notice: #{module_custom_time_pattern}/)[1].to_i
        end

        assert(local_custom_time2 > local_custom_time1, 'local custom time did not change as expected if at all')
        assert(module_custom_time2 > module_custom_time1, 'module custom time did not change as expected if at all')
      end
    end
  end
end
