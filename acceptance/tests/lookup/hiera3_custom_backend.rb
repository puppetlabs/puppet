test_name 'C99630: hiera v3 custom backend' do
  require 'puppet/acceptance/environment_utils.rb'
  extend Puppet::Acceptance::EnvironmentUtils
  require 'puppet/acceptance/temp_file_utils.rb'
  extend Puppet::Acceptance::TempFileUtils

tag 'audit:medium',
    'audit:acceptance',
    'audit:refactor',  # Master is not needed for this test. Refactor
                       # to use puppet apply with a local module tree.

  app_type        = File.basename(__FILE__, '.*')
  tmp_environment = mk_tmp_environment_with_teardown(master, app_type)
  fq_tmp_environmentpath  = "#{environmentpath}/#{tmp_environment}"
  puppetserver_config = "#{master['puppetserver-confdir']}/puppetserver.conf"
  existing_loadpath = read_tk_config_string(on(master, "cat #{puppetserver_config}").stdout.strip)['jruby-puppet']['ruby-load-path'].first
  confdir = puppet_config(master, 'confdir', section: 'master')

  hiera_conf_backup = master.tmpfile('C99629-hiera-yaml')

  step "backup global hiera.yaml" do
    on(master, "cp -a #{confdir}/hiera.yaml #{hiera_conf_backup}", :acceptable_exit_codes => [0,1])
  end

  teardown do
    step 'delete custom backend, restore default hiera config' do
      on(master, "rm #{existing_loadpath}/hiera/backend/custom_backend.rb", :acceptable_exit_codes => [0,1])
      on(master, "mv #{hiera_conf_backup} #{confdir}/hiera.yaml", :acceptable_exit_codes => [0,1])
    end
  end

  step "create hiera v5 config and v3 custom backend" do
    on(master, "cp #{confdir}/hiera.yaml /tmp")
    create_remote_file(master, "#{confdir}/hiera.yaml", <<-HIERA)
---
version: 5
hierarchy:
  - name: Test
    hiera3_backend: custom
    HIERA
    on(master, "chmod -R #{PUPPET_CODEDIR_PERMISSIONS} #{confdir}")

    on(master, "mkdir -p #{existing_loadpath}/hiera/backend/")
    custom_backend_rb = <<-RB
class Hiera
  module Backend
    class Custom_backend
      def lookup(key, scope, order_override, resolution_type, context)
        return 'custom value' unless (key == 'lookup_options')
      end
    end
  end
end
    RB
    create_remote_file(master, "#{existing_loadpath}/hiera/backend/custom_backend.rb", custom_backend_rb)
    on(master, "chmod #{PUPPET_CODEDIR_PERMISSIONS} #{existing_loadpath}/hiera/backend/custom_backend.rb")
  end

  step "create site.pp which calls lookup on our keys" do
    create_sitepp(master, tmp_environment, <<-SITE)
      notify { "${lookup('anykey')}": }
    SITE
    on(master, "chmod -R #{PUPPET_CODEDIR_PERMISSIONS} #{fq_tmp_environmentpath}")
  end

  step 'assert lookups using lookup subcommand on the master' do
    on(master, puppet('lookup', "--environment #{tmp_environment}", '--explain', 'anykey'), :accept_all_exit_codes => true) do |result|
      assert(result.exit_code == 0, "lookup subcommand didn't exit properly: (#{result.exit_code})")
      assert_match(/custom value/, result.stdout,
                   "lookup subcommand didn't find correct key")
    end
  end

  with_puppet_running_on(master,{}) do
    agents.each do |agent|
      step "agent manifest lookup on #{agent.hostname}" do
        on(agent, puppet('agent', "-t --server #{master.hostname} --environment #{tmp_environment}"),
           :accept_all_exit_codes => true) do |result|
          assert(result.exit_code == 2, "agent lookup didn't exit properly: (#{result.exit_code})")
          assert_match(/custom value/, result.stdout,
                       "agent lookup didn't find correct key")
        end
      end
    end
  end

end
