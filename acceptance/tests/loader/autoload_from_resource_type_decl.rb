# Verify Resource[]{} syntax works correctly with the autoloader
# and also works correctly with the loader and generated types
test_name 'C100303: Resource type statement works with auto-loader and loader with generated types' do
  tag 'risk:med'

  require 'puppet/acceptance/environment_utils.rb'
  extend Puppet::Acceptance::EnvironmentUtils

  app_type               = File.basename(__FILE__, '.*')
  tmp_environment        = mk_tmp_environment_with_teardown(master, app_type)
  fq_tmp_environmentpath = "#{environmentpath}/#{tmp_environment}"

  relative_type_dir    = "modules/one/lib/puppet/type"
  relative_type_1_path = "#{relative_type_dir}/type_tst1.rb"
  relative_type_2_path = "#{relative_type_dir}/type_tst2.rb"
  step 'create custom type in two environments' do
    on(master, "mkdir -p #{fq_tmp_environmentpath}/#{relative_type_dir}")

    custom_type_1 = <<-END
    Puppet::Type.newtype(:type_tst1) do
      newparam(:name, :namevar => true) do
        p "found_type_tst1"
      end
    end
    END
    custom_type_2 = <<-END
    Puppet::Type.newtype(:type_tst2) do
      newparam(:name, :namevar => true) do
        p "found_type_tst2"
      end
    end
    END
    create_remote_file(master, "#{fq_tmp_environmentpath}/#{relative_type_1_path}", custom_type_1)
    create_remote_file(master, "#{fq_tmp_environmentpath}/#{relative_type_2_path}", custom_type_2)

    site_pp = <<-PP
    Resource['type_tst1'] { 'found_type': }
    Resource['type_tst2'] { 'other_type_too': }
    PP
    create_sitepp(master, tmp_environment, site_pp)
  end

  on(master, "chmod -R 755 /tmp/#{tmp_environment}")

  with_puppet_running_on(master, {}) do
    agents.each do |agent|
      on(agent, puppet("agent -t --server #{master.hostname} --environment #{tmp_environment}"),
         :acceptable_exit_codes => 0) do |puppet_result|
        assert_match(/Notice: \/File\[.*\/lib\/puppet\/type\/type_tst1\.rb\]\/ensure: defined content as /, puppet_result.stdout,
                     "Expected to see notice for resource type: type_tst1")
        assert_match(/Notice: \/File\[.*\/lib\/puppet\/type\/type_tst2\.rb\]\/ensure: defined content as /, puppet_result.stdout,
                     "Expected to see notice for resource type: type_tst2")
        assert_match(/found_type_tst1/, puppet_result.stdout, "Expected to see output from new type: type_tst1")
        assert_match(/found_type_tst2/, puppet_result.stdout, "Expected to see output from new type: type_tst2")
      end
    end
  end

  step 'generate pcore files' do
    on(master, puppet("generate types --environment #{tmp_environment}")) do |puppet_result|
      assert_match(/Notice: Generating '.*\/type_tst1\.pp' using 'pcore' format/, puppet_result.stdout,
                   "Expected to see Generating message for type: type_tst1")
      assert_match(/Notice: Generating '.*\/type_tst2\.pp' using 'pcore' format/, puppet_result.stdout,
                   "Expected to see Generating message for type: type_tst2")
    end
  end

  # restart so that we will load and use the generated types
  on(master, "service #{master['puppetservice']} restart")

  agents.each do |agent|
    step 'rerun agents after generate, ensure proper runs' do
      on(agent, puppet("agent -t --server #{master.hostname} --environment #{tmp_environment}"),
         :acceptable_exit_codes => 0) do |puppet_result|
        assert_match(/found_type_tst1/, puppet_result.stdout, "Expected to see output from new type: type_tst1")
        assert_match(/found_type_tst2/, puppet_result.stdout, "Expected to see output from new type: type_tst2")
        refute_match(/Notice: \/File\[.*\/lib\/puppet\/type\/type_tst1\.rb\]\/ensure: defined content as /, puppet_result.stdout,
                     "Unexpected notice for pre-exsiting generated type: type_tst1")
        refute_match(/Notice: \/File\[.*\/lib\/puppet\/type\/type_tst2\.rb\]\/ensure: defined content as /, puppet_result.stdout,
                     "Unexpected notice for pre-exsiting generated type: type_tst2")
      end
    end
  end
end
