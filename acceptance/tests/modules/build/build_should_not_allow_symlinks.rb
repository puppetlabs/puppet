test_name "puppet module build should verify there are no symlinks in module"

tag 'audit:medium',
    'audit:acceptance'

confine :except, :platform => 'windows'

modauthor = 'foo'
modname = 'bar'
defaultversion = '0.1.0'
buildpath = "#{modname}/pkg/#{modname}-#{defaultversion}"

agents.each do |agent|

  if on(agent, facter("fips_enabled")).stdout =~ /true/
    puts "Module build, loading and installing is not supported on fips enabled platforms"
    next
  end

  tmpdir = agent.tmpdir('pmtbuildsymlink')

  teardown do
    on(agent, "rm -rf #{modname}")
    on(agent, "rm -rf #{tmpdir}")
  end

  step 'Generate module' do
    on(agent, puppet("module generate #{modauthor}-#{modname} --skip-interview"))
  end

  step 'Add symlink to module' do
    on(agent, "touch #{tmpdir}/hello")
    on(agent, "ln -s #{tmpdir}/hello #{modname}/examples/symlink")
  end

  step 'Build module should fail with message about needing symlinks removed' do
    on(agent, puppet("module build #{modname}"), :acceptable_exit_codes => [1]) do |res|
      fail_test('Proper failure message not displayed') unless res.stderr.include? 'Symlinks in modules are unsupported'
    end
  end

end
