test_name "puppet module build (agent)"

tag 'audit:medium',
    'audit:acceptance'

agents.each do |agent|

  if on(agent, facter("fips_enabled")).stdout =~ /true/
    puts "Module build, loading and installing not supported on fips enabled platforms"
    next
  end

  teardown do
    on agent, 'rm -rf bar'
  end

  step 'setup: ensure clean working directory'
  on agent, 'rm -rf bar'

  step 'generate'
  on(agent, puppet('module generate foo-bar --skip-interview'))

  step 'build'
  on(agent, puppet('module build bar')) do
    assert_match(/Module built: .*\/bar\/pkg\/foo-bar-.*\.tar\.gz/, stdout) unless agent['locale'] == 'ja'
  end
end
