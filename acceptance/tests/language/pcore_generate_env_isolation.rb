test_name 'C98345: ensure puppet generate assures env. isolation' do
  require 'puppet/acceptance/environment_utils.rb'
  extend Puppet::Acceptance::EnvironmentUtils

tag 'audit:medium',
    'audit:integration',
    'server'

  app_type        = File.basename(__FILE__, '.*')
  tmp_environment = mk_tmp_environment_with_teardown(master, app_type)
  tmp_environment2 = mk_tmp_environment_with_teardown(master, app_type)
  fq_tmp_environmentpath  = "#{environmentpath}/#{tmp_environment}"
  fq_tmp_environmentpath2  = "#{environmentpath}/#{tmp_environment2}"

  type_name = 'conflicting'
  relative_type_dir  = 'modules/conflict/lib/puppet/type'
  relative_type_path = "#{relative_type_dir}/#{type_name}.rb"
  step 'create custom type in two environments' do
    on(master, "mkdir -p #{fq_tmp_environmentpath}/#{relative_type_dir}")
    on(master, "mkdir -p #{fq_tmp_environmentpath2}/#{relative_type_dir}")

    custom_type1 = <<-END
    Puppet::Type.newtype(:#{type_name}) do
      newparam :name, :namevar => true
    END
    custom_type2 =  "#{custom_type1}"
    custom_type2 << "      newparam :other\n"
    custom_type1 << "    end\n"
    custom_type2 << "    end\n"
    create_remote_file(master, "#{fq_tmp_environmentpath}/#{relative_type_path}",  custom_type1)
    create_remote_file(master, "#{fq_tmp_environmentpath2}/#{relative_type_path}", custom_type2)

    site_pp1 = <<-PP
    notify{$environment:}
    #{type_name}{"somename":}
    PP
    site_pp2 = <<-PP
    notify{$environment:}
    #{type_name}{"somename": other => "uhoh"}
    PP
    create_sitepp(master, tmp_environment,  site_pp1)
    create_sitepp(master, tmp_environment2, site_pp2)
  end

  on master, "chmod -R 755 /tmp/#{tmp_environment}"
  on master, "chmod -R 755 /tmp/#{tmp_environment2}"

  with_puppet_running_on(master,{}) do
    agents.each do |agent|
      on(agent, puppet("agent -t --server #{master.hostname} --environment #{tmp_environment}"),
         :acceptable_exit_codes => 2)
      step 'run agent in environment with type with an extra parameter. try to use this parameter' do
        on(agent, puppet("agent -t --server #{master.hostname} --environment #{tmp_environment2}"),
           :accept_all_exit_codes => true) do |result|
          unless agent['locale'] == 'ja'
            assert_match("Error: no parameter named 'other'", result.output,
                         'did not produce environment isolation issue as expected')
          end
        end
      end
    end

    step 'generate pcore files' do
      on(master, puppet("generate types --environment #{tmp_environment}"))
      on(master, puppet("generate types --environment #{tmp_environment2}"))
    end

    agents.each do |agent|
      step 'rerun agents after generate, ensure proper runs' do
        on(agent, puppet("agent -t --server #{master.hostname} --environment #{tmp_environment}"),
           :acceptable_exit_codes => 2)
        on(agent, puppet("agent -t --server #{master.hostname} --environment #{tmp_environment2}"),
           :acceptable_exit_codes => 2)
      end
    end
  end

end
