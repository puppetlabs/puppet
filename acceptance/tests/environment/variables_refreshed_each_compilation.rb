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
  on(master, "mkdir -p #{fq_tmp_environmentpath}/modules/uptime/{manifests,functions}")
  create_remote_file(master, "#{fq_tmp_environmentpath}/modules/uptime/manifests/init.pp", <<-FILE)
    class uptime {
      notify { 'current uptime':
        message => uptime::my_system_uptime()
      }
    }
  FILE
  create_remote_file(master, "#{fq_tmp_environmentpath}/modules/uptime/functions/my_system_uptime.pp", <<-FILE)
    function uptime::my_system_uptime() {
      $facts['system_uptime']
    }
  FILE
  create_sitepp(master, tmp_environment, <<-SITE)
    function bar() {
      $facts['system_uptime']['seconds']
    }
    class foo::bar {
      notify { "local_${bar()}_local": }
    }
    include foo::bar
    include uptime
  SITE
  on(master, "chmod -R 0777 #{fq_tmp_environmentpath}/")

  step "run agent in #{tmp_environment}, ensure it increments the uptime with each run" do
    with_puppet_running_on(master,{}) do
      uptime = nil
      module_uptime = nil
      local_uptime_pattern = 'local_(\d+)_local'
      agents.each do |agent|
        on(agent, puppet("agent -t --server #{master.hostname} --environment #{tmp_environment}"),
           :accept_all_exit_codes => true) do |result|
          assert_equal(2, result.exit_code, 'wrong exit_code')
          assert_match(/Notice: #{local_uptime_pattern}/, result.stdout, 'first uptime was not as expected')
          assert_match(/"seconds"=>\d+,/, result.stdout, 'first module uptime was not as expected')
          uptime = Integer(result.stdout.match(/Notice: #{local_uptime_pattern}/)[1])
          module_uptime = Integer(result.stdout.match(/"seconds"=>(\d+),/)[1])
        end
        if agent.platform =~ /solaris|aix/
          sleep 61  # See FACT-1497;
        else
          sleep 1
        end
        on(agent, puppet("agent -t --server #{master.hostname} --environment #{tmp_environment}"),
           :accept_all_exit_codes => true) do |result|
          assert_equal(2, result.exit_code, 'wrong exit_code')
          assert_match(/Notice: #{local_uptime_pattern}/, result.stdout, 'second uptime was not as expected')
          assert_match(/"seconds"=>\d+,/, result.stdout, 'second module uptime was not as expected')
          uptime2 = Integer(result.stdout.match(/Notice: #{local_uptime_pattern}/)[1])
          module_uptime2 = Integer(result.stdout.match(/"seconds"=>(\d+),/)[1])
          assert(uptime2 > uptime, 'uptime did not change')
          assert(module_uptime2 > module_uptime, 'module based uptime did not change')
        end
      end
    end
  end

end
