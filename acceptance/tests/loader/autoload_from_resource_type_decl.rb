test_name 'C100303: Resource type statement triggered auto-loading works both with and without generated types' do
  tag 'risk:medium'

  require 'puppet/acceptance/environment_utils.rb'
  extend Puppet::Acceptance::EnvironmentUtils

  require 'master_manipulator'
  extend MasterManipulator::Log

  puppet_server_log      = puppet_server_log_path(master)
  app_type               = File.basename(__FILE__, '.*')
  tmp_environment        = mk_tmp_environment_with_teardown(master, app_type)
  fq_tmp_environmentpath = "#{environmentpath}/#{tmp_environment}"

  relative_type_dir    = 'modules/one/lib/puppet/type'
  relative_type_1_path = "#{relative_type_dir}/type_tst.rb"
  step 'create custom type' do
    on(master, "mkdir -p #{fq_tmp_environmentpath}/#{relative_type_dir}")

    custom_type = <<-END
    Puppet::Type.newtype(:type_tst) do
      newparam(:name, :namevar => true) do
        Puppet.notice("found_type_tst")
      end
    end
    END
    create_remote_file(master, "#{fq_tmp_environmentpath}/#{relative_type_1_path}", custom_type)

    site_pp = <<-PP
    Resource['type_tst'] { 'found_type': }
    PP
    create_sitepp(master, tmp_environment, site_pp)
  end

  on(master, "chmod -R 755 /tmp/#{tmp_environment}")

  # rotate the server log so that it won't rotate during the test
  rotate_puppet_server_log(master)

  with_puppet_running_on(master, {}) do
    agents.each do |agent|
      on(agent, puppet("agent -t --server #{master.hostname} --environment #{tmp_environment}"),
         :acceptable_exit_codes => 0) do |puppet_result|
        assert_match(/Notice: found_type_tst/, puppet_result.stdout, 'Expected to see output from new type: type_tst')
      end
    end
  end
  type_message_count = 0
  step 'ensure that we got a message for the type' do
    on(master, "cat #{puppet_server_log}") do |cat_result|
      assert_match(/\[puppetserver\] Puppet found_type_tst/, cat_result.stdout, 'Expected to see entry for new type type_tst')
      type_message_count = cat_result.stdout.split(/\[puppetserver\] Puppet found_type_tst/).length
    end
  end

  step 'generate pcore files' do
    on(master, puppet("generate types --environment #{tmp_environment}")) do |puppet_result|
      assert_match(/Notice: Generating '.*\/type_tst\.pp' using 'pcore' format/, puppet_result.stdout,
                   'Expected to see Generating message for type: type_tst')
      assert_match(/Notice: found_type_tst/, puppet_result.stdout, 'Expected to see generate output from new type: type_tst')
    end
  end

  # restart so that we will load and use the generated types
  on(master, "service #{master['puppetservice']} restart")

  agents.each do |agent|
    step 'rerun agents after generate, ensure proper runs' do
      on(agent, puppet("agent -t --server #{master.hostname} --environment #{tmp_environment}"),
         :acceptable_exit_codes => 0) do |puppet_result|
        assert_match(/Notice: found_type_tst/, puppet_result.stdout, 'Expected to see output from new type: type_tst')
      end
    end
  end

  step 'ensure that there are no new messages' do
    on(master, "cat #{puppet_server_log}") do |cat_result|
      type_message_recount = cat_result.stdout.split(/\[puppetserver\] Puppet found_type_tst/).length
      step "COUNT #{type_message_count} #{type_message_recount}"
      assert_equal(type_message_count, type_message_recount, 'Expected the message count to not change')
    end
  end
end
