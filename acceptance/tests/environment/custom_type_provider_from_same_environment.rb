test_name 'C59122: ensure provider from same env as custom type' do
require 'puppet/acceptance/environment_utils'
extend Puppet::Acceptance::EnvironmentUtils

tag 'audit:medium',
    'audit:integration',  # This behavior is specific to the master to 'do the right thing'
    'server'

  app_type        = File.basename(__FILE__, '.*')
  tmp_environment = mk_tmp_environment_with_teardown(master, app_type)
  file_correct    = "#{tmp_environment}-correct.txt"
  file_wrong      = "#{tmp_environment}-wrong.txt"
  fq_tmp_environmentpath  = "#{environmentpath}/#{tmp_environment}"
  fq_prod_environmentpath = "#{environmentpath}/production"

  teardown do
    step 'clean out production env' do
      on(master, "rm -rf #{fq_prod_environmentpath}/modules/*",         :accept_all_exit_codes => true)
      on(master, "rm     #{fq_prod_environmentpath}/manifests/site.pp", :accept_all_exit_codes => true)
    end
    step 'clean out file resources' do
      on(hosts, "rm #{file_correct} #{file_wrong}", :accept_all_exit_codes => true)
    end
  end

  step "create a custom type and provider in each of production and #{tmp_environment}" do
    type_name               = 'test_custom_type'
    provider_name           = 'universal'
    type_content            = <<TYPE
      Puppet::Type.newtype(:#{type_name}) do
        @doc = "Manage a file (the simple version)."
        ensurable
        newparam(:name) do
          desc "The full path to the file."
        end
      end
TYPE

    def provider_content(file_file_content, type_name, provider_name)
      return <<PROVIDER
        Puppet::Type.type(:#{type_name}).provide(:#{provider_name}) do
          desc "#{provider_name} file mgmt, yo"
          def create
            File.open(@resource[:name], "w") { |f| f.puts "#{file_file_content}!" }
          end
          def destroy
            File.unlink(@resource[:name])
          end
          def exists?
            File.exists?(@resource[:name])
          end
        end
PROVIDER
    end

    manifest = <<MANIFEST
File { ensure => directory }
file {
       '#{fq_tmp_environmentpath}/modules/simple_type':;
       '#{fq_tmp_environmentpath}/modules/simple_type/lib':;
       '#{fq_tmp_environmentpath}/modules/simple_type/lib/puppet':;
       '#{fq_tmp_environmentpath}/modules/simple_type/lib/puppet/type/':;
       '#{fq_tmp_environmentpath}/modules/simple_type/lib/puppet/provider/':;
       '#{fq_tmp_environmentpath}/modules/simple_type/lib/puppet/provider/#{type_name}':;
       '#{fq_prod_environmentpath}/modules/simple_type':;
       '#{fq_prod_environmentpath}/modules/simple_type/lib':;
       '#{fq_prod_environmentpath}/modules/simple_type/lib/puppet':;
       '#{fq_prod_environmentpath}/modules/simple_type/lib/puppet/type/':;
       '#{fq_prod_environmentpath}/modules/simple_type/lib/puppet/provider/':;
       '#{fq_prod_environmentpath}/modules/simple_type/lib/puppet/provider/#{type_name}':;
}
file { '#{fq_tmp_environmentpath}/modules/simple_type/lib/puppet/type/#{type_name}.rb':
  ensure => file,
    content => '#{type_content}',
}
file { '#{fq_prod_environmentpath}/modules/simple_type/lib/puppet/type/#{type_name}.rb':
  ensure => file,
    content => '#{type_content}',
}
file { '#{fq_tmp_environmentpath}/modules/simple_type/lib/puppet/provider/#{type_name}/#{provider_name}.rb':
  ensure => file,
    content => '#{provider_content('correct', type_name, provider_name)}',
}
file { '#{fq_prod_environmentpath}/modules/simple_type/lib/puppet/provider/#{type_name}/#{provider_name}.rb':
  ensure => file,
    content => '#{provider_content('wrong', type_name, provider_name)}',
}
file { '#{fq_tmp_environmentpath}/manifests/site.pp':
  ensure => file,
    content => 'node default { #{type_name}{"#{file_correct}": ensure=>present} }',
}
file { '#{fq_prod_environmentpath}/manifests/site.pp':
  ensure => file,
    content => 'node default { #{type_name}{"#{file_wrong}": ensure=>present} }',
}
MANIFEST
    apply_manifest_on(master, manifest, :catch_failures => true)
  end

  step "run agent in #{tmp_environment}, ensure it finds the correct provider" do
    with_puppet_running_on(master,{}) do
      agents.each do |agent|
        on(agent, puppet("agent -t --server #{master.hostname} --environment #{tmp_environment}"),
          :accept_all_exit_codes => true) do |result|
          assert_equal(2, result.exit_code, 'agent did not exit with the correct code of 2')
          assert_match(/#{file_correct}/, result.stdout, 'agent did not ensure the correct file')
          assert(agent.file_exist?(file_correct), 'puppet did not create the file')
        end
      end
    end
  end

end
