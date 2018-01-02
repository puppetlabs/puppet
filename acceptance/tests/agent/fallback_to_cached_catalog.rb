test_name "fallback to the cached catalog"

tag 'audit:medium',
    'audit:integration', # This test is not OS sensitive.
    'audit:refactor'     # A catalog fixture can be used for this test. Remove the usage of `with_puppet_running_on`.

step "run agents once to cache the catalog" do
  with_puppet_running_on master, {} do
    on(agents, puppet("agent -t --server #{master}"))
  end
end

step "run agents again, verify they use cached catalog" do
  agents.each do |agent|
    # can't use --test, because that will set usecacheonfailure=false
    # We use a server that the agent can't possibly talk to in order
    # to guarantee that no communication can take place.
    on(agent, puppet("agent --onetime --no-daemonize --server puppet.example.com --verbose")) do |result|
      assert_match(/Using cached catalog/, result.stdout) unless agent['locale'] == 'ja'
    end
  end
end
