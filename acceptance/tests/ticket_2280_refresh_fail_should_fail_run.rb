test_name 'C100297 - A resource triggered by a refresh that fails should be reported as a failure when using --detailed-exitcodes' do

  tag 'audit:medium',
      'audit:integration' # Service type interaction with --detailed-exitcodes

  manifest =<<EOS
    exec{'true':
      command => 'true',
      path => ['/bin', '/usr/bin'],
    }

    exec{'false':
      command => 'false',
      path => ['/bin', '/usr/bin'],
      refreshonly => true,
      subscribe => Exec['true'],
    }

    exec{'require_echo':
      command => 'echo "This should not happen due to a failed requirement."',
      path => ['/bin', '/usr/bin'],
      logoutput => true,
      require => Exec['false'],
    }
EOS

  agents.each do |agent|
    step 'Apply manifest with fail on refresh. Ensure that this results in a failed dependency' do
      apply_manifest_on(agent, manifest, :expect_failures => true) do |res|
        assert_no_match(/require_echo.*returns: executed successfully/, res.stdout)
        assert_match(/require_echo.*Skipping because of failed dependencies/, res.stderr) unless agent['locale'] == 'ja'
      end
    end
  end

end
