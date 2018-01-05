test_name "puppet module build should not result in changed files"

tag 'audit:medium',
    'audit:acceptance'

modauthor = 'foo'
modname = 'bar'
defaultversion = '0.1.0'
buildpath = "#{modname}/pkg/#{modauthor}-#{modname}-#{defaultversion}"

agents.each do |agent|

  if on(agent, facter("fips_enabled")).stdout =~ /true/
    puts "Module build, loading and installing not supported on fips enabled platforms"
    next
  end

  teardown do
    on(agent, "rm -rf #{modname}")
  end

  step 'Generate module' do
    on(agent, puppet("module generate #{modauthor}-#{modname} --skip-interview"))
  end

  step 'Build module' do
    on(agent, puppet("module build #{modname}"))
    on(agent, "test -d #{buildpath}")
  end

  step 'Verify fresh build has no changes' do
    on(agent, puppet("module changes #{buildpath}")) do |res|
      fail_test('Changed files found') if res.stderr.include? 'modified'
    end
  end
end
