test_name 'C100560: puppet agent run output falls back to english when language not available' do
  # No confines because even on non-translation supported OS' we should still fall back to english

  tag 'audit:medium',
      'audit:acceptance'

  agents.each do |agent|
    step 'Run Puppet apply with language Hungarian and check the output' do
      unsupported_language='hu_HU'
      on(agent, puppet("agent -t --server #{master}",
                       'ENV' => {'LANG' => unsupported_language, 'LANGUAGE' => ''})) do |apply_result|
        assert_match(/Applying configuration version '[^']*'/, apply_result.stdout,
                     'agent run should default to english translation')
        assert_match(/Applied catalog in [0-9.]* seconds/, apply_result.stdout,
                     'agent run should default to english translation')
      end
    end
  end
end
