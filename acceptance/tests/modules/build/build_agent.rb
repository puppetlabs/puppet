test_name "puppet module build (agent)"

agents.each do |agent|
  teardown do
    on agent, 'rm -rf bar'
  end

  step 'generate'
  on(agent, puppet('module generate foo-bar --skip-interview'))

  step 'build'
  on(agent, puppet('module build bar')) do
    assert_match(/Module built: .*\/bar\/pkg\/foo-bar-.*\.tar\.gz/, stdout)
  end
end
