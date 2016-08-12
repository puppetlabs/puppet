test_name 'C98097 - generated pcore resource types should be loaded instead of ruby for custom types' do
  environment = 'production'
  step 'setup - install module with custom ruby resource type' do
    agents.each do |agent|
      #{{{
      testdir = agent.tmpdir('c98097')
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

      apply_manifest_on(agents, <<MANIFEST, :catch_failures => true)
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

      backup_file = backup_the_file(agent, agent.puppet('master')['confdir'], testdir, 'puppet.conf')
      lay_down_new_puppet_conf agent, conf_opts, testdir

      teardown do
        restore_puppet_conf_from_backup( agent, backup_file )
      end
      #}}}
    end

    catalog_results = {}
    agents.each do |agent|
      catalog_results[agent.hostname] = { 'ruby_cat' => '', 'pcore_cat' => '' }
    end

    step 'compile catalog using ruby resource' do
      agents.each do |agent|
        on agent, puppet('master', '--compile', agent.hostname) do |result|
          assert_match(/running ruby code/, result.stderr)
          catalog_results[agent.hostname]['ruby_cat'] = JSON.parse(result.stdout.sub(/^[^{]+/,''))
        end
      end
    end

    step 'generate pcore type from ruby type' do
      agents.each do |agent|
        on agent, puppet('generate', 'types', '--environment', environment)
      end
    end

    step 'compile catalog and make sure that ruby code is NOT executed' do
      agents.each do |agent|
        on agent, puppet('master', '--compile', agent.hostname) do |result|
          assert_no_match(/running ruby code/, result.stderr)
          catalog_results[agent.hostname]['pcore_cat'] = JSON.parse(result.stdout.sub(/^[^{]+/,''))
        end
      end
    end

    step 'ensure that the resources created in the catalog using ruby and pcore are the same' do
      agents.each do |agent|
        assert_equal(catalog_results[agent.hostname]['ruby_cat']['resources'], catalog_results[agent.hostname]['pcore_cat']['resources'])
      end
    end

  end
end
