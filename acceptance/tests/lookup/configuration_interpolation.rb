test_name 'C99578: lookup should allow interpolation in configs and data' do
  require 'puppet/acceptance/environment_utils.rb'
  extend Puppet::Acceptance::EnvironmentUtils

  app_type        = File.basename(__FILE__, '.*')
  tmp_environment = mk_tmp_environment_with_teardown(master, app_type)
  fq_tmp_environmentpath  = "#{environmentpath}/#{tmp_environment}"
  master_confdir = master.puppet('master')['confdir']

  step "backup hiera config file" do
    on master, "cp #{master_confdir}/hiera.yaml #{master_confdir}/hiera.bak"
  end

  teardown do
    on master, "mv #{master_confdir}/hiera.bak #{master_confdir}/hiera.yaml"
  end

  step "create hiera configs in #{tmp_environment} and global" do
    codedir = master.puppet('master')['codedir']

    step "create global hiera.yaml and module data" do
      create_remote_file(master, "#{master_confdir}/hiera.yaml", <<-HIERA)
---
:backends:
  - "yaml"
:hierarchy:
  - "%{calling_class_path}"
  - "%{calling_class}"
  - "%{calling_module}"
  - "common"
      HIERA

      on(master, "mkdir -p #{fq_tmp_environmentpath}/hieradata/")
      on(master, "mkdir -p #{fq_tmp_environmentpath}/modules/some_mod/manifests")
      create_remote_file(master, "#{fq_tmp_environmentpath}/modules/some_mod/manifests/init.pp", <<-PP)
class some_mod {
  notify { "${lookup('environment_key')}": }
}
      PP

      create_remote_file(master, "#{fq_tmp_environmentpath}/hieradata/some_mod.yaml", <<-YAML)
---
environment_key: "env value"
      YAML

      create_sitepp(master, tmp_environment, <<-SITE)
include some_mod
      SITE

      on(master, "chmod -R 775 #{fq_tmp_environmentpath}")
      on(master, "chmod -R 775 #{master_confdir}")
    end
  end

  with_puppet_running_on(master,{}) do
    agents.each do |agent|
      step "agent lookup" do
        on(agent, puppet('agent', "-t --server #{master.hostname} --environment #{tmp_environment} --debug"),
           :accept_all_exit_codes => true) do |result|
          assert(result.exit_code == 2, "agent lookup didn't exit properly: (#{result.exit_code})")
          assert_match(/env value/, result.stdout,
                       "agent lookup didn't find correct key")
        end
      end
    end
  end

end
