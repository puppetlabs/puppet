test_name 'C98097 - generated pcore resource types should be loaded instead of ruby for custom types' do

tag 'audit:medium',
    'audit:integration',
    'audit:refactor',    # use `mk_temp_environment_with_teardown` helper to build environment
    'server'

  environment = 'production'
  step 'setup - install module with custom ruby resource type' do
    #{{{
    testdir = master.tmpdir('c98097')
    codedir = "#{testdir}/codedir"

    site_manifest_content =<<EOM
node default {
  notice(mycustomtype{"foobar":})
}
EOM

    custom_type_content =<<EOM
Puppet::Type.newtype(:mycustomtype) do
  @doc = "Create a new mycustomtype thing."

  newparam(:name, :namevar => true) do
    desc "Name of mycustomtype instance"
    $stderr.puts "this indicates that we are running ruby code and should not be seen when running generated pcore resource"
  end

  def refresh
  end

end
EOM

    apply_manifest_on(master, <<MANIFEST, :catch_failures => true)
File {
  ensure => directory,
  mode   => "0755",
}

file {[
  '#{codedir}',
  '#{codedir}/environments',
  '#{codedir}/environments/#{environment}',
  '#{codedir}/environments/#{environment}/manifests',
  '#{codedir}/environments/#{environment}/modules',
  '#{codedir}/environments/#{environment}/modules/mymodule',
  '#{codedir}/environments/#{environment}/modules/mymodule/manifests',
  '#{codedir}/environments/#{environment}/modules/mymodule/lib',
  '#{codedir}/environments/#{environment}/modules/mymodule/lib/puppet',
  '#{codedir}/environments/#{environment}/modules/mymodule/lib/puppet/type'
  ]:
}

file { '#{codedir}/environments/#{environment}/manifests/site.pp':
  ensure => file,
  content => '#{site_manifest_content}',
}

file { '#{codedir}/environments/#{environment}/modules/mymodule/lib/puppet/type/mycustomtype.rb':
  ensure => file,
  content => '#{custom_type_content}',
}
MANIFEST

    conf_opts = {
      'main' => {
        'environmentpath' => "#{codedir}/environments"
      }
    }

    backup_file = backup_the_file(master, puppet_config(master, 'confdir', section: 'master'), testdir, 'puppet.conf')
    lay_down_new_puppet_conf master, conf_opts, testdir

    teardown do
      restore_puppet_conf_from_backup( master, backup_file )
      # See PUP-6995
      on(master, "rm -f #{puppet_config(master, 'yamldir', section: 'master')}/node/*.yaml")
    end
    #}}}

    catalog_results = {}
    catalog_results[master.hostname] = { 'ruby_cat' => '', 'pcore_cat' => '' }

    step 'compile catalog using ruby resource' do
      on master, puppet('catalog', 'find', master.hostname) do |result|
        assert_match(/running ruby code/, result.stderr)
        catalog_results[master.hostname]['ruby_cat'] = JSON.parse(result.stdout.sub(/^[^{]+/,''))
      end
    end

    step 'generate pcore type from ruby type' do
      on master, puppet('generate', 'types', '--environment', environment)
    end

    step 'compile catalog and make sure that ruby code is NOT executed' do
      on master, puppet('catalog', 'find', master.hostname) do |result|
        assert_no_match(/running ruby code/, result.stderr)
        catalog_results[master.hostname]['pcore_cat'] = JSON.parse(result.stdout.sub(/^[^{]+/,''))
      end
    end

    step 'ensure that the resources created in the catalog using ruby and pcore are the same' do
      assert_equal(catalog_results[master.hostname]['ruby_cat']['resources'], catalog_results[master.hostname]['pcore_cat']['resources'])
    end

  end
end
