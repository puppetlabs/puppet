test_name "C97899 - Agent run should fail if environment is unreadable" do
  skip_test 'requires a puppetserver master for managing the environment' if hosts_with_role(hosts, 'master').length == 0 or not @options[:is_puppetserver]
  jruby_version = on(master, 'puppetserver ruby --version').stdout
  skip_test 'This is only valid on JRuby 1.7' unless jruby_version =~ /^jruby 1\.7/

  testdir = ''
  env_path = ''
  test_env = ''

  step 'setup environments' do
    testdir = create_tmpdir_for_user master, 'c97899_unreadable_envdir'
    env_path = "#{testdir}/environments"
    test_env = "#{env_path}/testing"

    apply_manifest_on(master, <<-MANIFEST, :catch_failures => true)
      File {
        ensure => directory,
        mode => "0770",
        owner => #{master.puppet['user']},
        group => #{master.puppet['group']},
      }
      file {
        '#{env_path}':;
        '#{env_path}/production':;
        '#{test_env}':;
        '#{test_env}/manifests':;
        '#{test_env}/modules':;
      }
      file { '#{test_env}/manifests/site.pp':
        ensure => file,
        mode => "0640",
        content => 'node default { notify { "Hello agent": } }',
      }
    MANIFEST
  end

  step 'change permissions of envdir to 644' do
    on(master, "chmod 644 #{test_env}")
  end

  step 'verify environment fails with puppet agent run' do
    master_opts = {
      'main' => {
        'environmentpath' => env_path,
      }
    }
    with_puppet_running_on master, master_opts, testdir do
      agents.each do |agent|
        on(agent, puppet("agent --test --server #{master} --environment testing"), :accept_all_exit_codes => true) do |result|
          refute_equal(2, result.exit_code, 'agent run should not apply changes')
          expect_failure('expected to fail until PUP-6241 is resolved') do
            refute_equal(0, result.exit_code, 'agent run should not succeed')
            refute_empty(result.stderr, 'an appropriate error is expected')
          end
        end
      end
    end
  end

end
