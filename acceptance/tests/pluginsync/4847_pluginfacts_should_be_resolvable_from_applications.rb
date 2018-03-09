test_name "Pluginsync'ed custom facts should be resolvable during application runs" do

  tag 'audit:medium',
      'audit:integration'

  #
  # This test is intended to ensure that custom facts downloaded onto an agent via
  # pluginsync are resolvable by puppet applications besides agent/apply.
  #

  require 'puppet/acceptance/environment_utils'
  extend Puppet::Acceptance::EnvironmentUtils

  tmp_environment         = mk_tmp_environment_with_teardown(master, 'resolve')
  master_module_dir       = "#{environmentpath}/#{tmp_environment}/modules/module_name"
  master_type_dir         = "#{master_module_dir}/lib/puppet/type"
  master_module_type_file = "#{master_type_dir}/test4847.rb"
  master_provider_dir     = "#{master_module_dir}/lib/puppet/provider/test4847"
  master_provider_file    = "#{master_provider_dir}/only.rb"
  master_facter_dir       = "#{master_module_dir}/lib/facter"
  master_facter_file      = "#{master_facter_dir}/foo.rb"
  on(master, "mkdir -p '#{master_type_dir}' '#{master_provider_dir}' '#{master_facter_dir}'")
  teardown do
    on(master, "rm -rf '#{master_module_dir}'")
  end

  test_type = <<-TYPE
      Puppet::Type.newtype(:test4847) do
        newparam(:name, :namevar => true)
      end
  TYPE
  create_remote_file(master, master_module_type_file, test_type)

  test_provider = <<-PROVIDER
      Puppet::Type.type(:test4847).provide(:only) do
        def self.instances
          warn "fact foo=\#{Facter.value('foo')}"
          []
        end
      end
  PROVIDER
  create_remote_file(master, master_provider_file, test_provider)

  foo_fact_content = <<-FACT_FOO
      Facter.add('foo') do
        setcode do
          'bar'
        end
      end
  FACT_FOO
  create_remote_file(master, master_facter_file, foo_fact_content)
  on(master, "chmod 755 '#{master_module_type_file}' '#{master_provider_file}' '#{master_facter_file}'")

  with_puppet_running_on(master, {}) do
    agents.each do |agent|
      on(agent, puppet("agent -t --server #{master} --environment #{tmp_environment}"))
      on(agent, puppet('resource test4847')) do |result|
        assert_match(/fact foo=bar/, result.stderr)
      end
    end
  end
end
