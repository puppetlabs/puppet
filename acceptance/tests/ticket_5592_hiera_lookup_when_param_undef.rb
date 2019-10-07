test_name 'Ensure hiera lookup occurs if class param is undef' do

  tag 'audit:medium',
      'audit:unit'    # basic auto lookup functionality

  agents.each do |agent|

    testdir = agent.tmpdir('undef')

    step 'Setup - create hiera data file and test module' do

##{{{
      manifest =<<-PP
File {
  ensure => directory,
  mode => "0750",
}

file {
  '#{testdir}':;
  '#{testdir}/hieradata':;
  '#{testdir}/environments':;
  '#{testdir}/environments/production':;
  '#{testdir}/environments/production/modules':;
}

file { '#{testdir}/hiera.yaml':
  ensure  => file,
  content => '---
    :backends:
      - "yaml"
    :hierarchy:
      - "global"
    :yaml:
      :datadir: "#{testdir}/hieradata"
  ',
  mode => "0640",
}

file { '#{testdir}/hieradata/global.yaml':
  ensure  => file,
  content => "test::my_param: 'hiera lookup value'",
  mode => "0640",
}

file {
  '#{testdir}/environments/production/modules/test':;
  '#{testdir}/environments/production/modules/test/manifests':;
}

file { '#{testdir}/environments/production/modules/test/manifests/init.pp':
  ensure => file,
  content => '
    class test (
      $my_param = "class default value",
    ) {
      notice($my_param)
    }',
  mode => "0640",
}
PP
#}}}

      apply_manifest_on(agent, manifest, :catch_failures => true)
    end

    step 'Invoke class with undef param and verify hiera value was applied' do
      on(agent, puppet('apply', "-e 'class {\"test\": my_param => undef }'", "--modulepath=#{testdir}/environments/production/modules", "--hiera_config=#{testdir}/hiera.yaml" ), :acceptable_exit_codes => [0,2])
      assert_match("hiera lookup value", stdout)
    end

  end

end
