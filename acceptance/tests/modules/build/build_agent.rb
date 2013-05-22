test_name "puppet module build (agent)"

agents.each do |agent|
  teardown do
    on agent, 'rm -rf foo-bar'
  end

  step 'generate'
  on(agent, puppet('module generate foo-bar'))

  step 'build'
  on(agent, puppet('module build foo-bar')) do
    assert_match(/Module built: .*\/foo-bar\/pkg\/foo-bar-.*\.tar\.gz/, stdout)
  end
end
