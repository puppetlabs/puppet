test_name "fallback to the cached catalog"

step "run agents once to cache the catalog" do
  with_puppet_running_on master, {} do
    on(agents, puppet("agent -t --server #{master}"))
  end
end

step "run agents again, verify they use cached catalog" do
  agents.each do |agent|
    # can't use --test, because that will set usecacheonfailure=false
    on(agent, puppet("agent --onetime --no-daemonize --server #{master} --verbose")) do |result|
      assert_match(/Using cached catalog/, result.stdout)
    end
  end
end
