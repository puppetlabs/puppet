test_name '--test flag should override use_cached_catalog'

with_puppet_running_on master, {} do
  step "run agents once to cache the catalog" do
    on(agents, puppet("agent -t --server #{master}"))
  end
  step "run agents again, verify that --test overrides cached catalog" do
    agents.each do |agent|
      on(agent, puppet("agent --test --use_cached_catalog --server #{master}")) do |result|
        assert_no_match(/Using cached catalog/, result.stdout)
      end
    end
  end
end
