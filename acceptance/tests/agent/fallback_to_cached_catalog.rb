test_name "fallback to the cached catalog" do
  tag 'audit:medium',
      'audit:integration' # This test is not OS sensitive.

  fixture_dir = File.expand_path(File.join(File.dirname(__FILE__),
                                           "../../fixtures"))

  agents.each do |agent|
    skip_test("cannot assert regex match for Japanese") if agent["locale"] == "ja"
    step "seed catalog cache with fixture" do
      node_name = agent.node_name
      catalogdir = File.join(agent.puppet["vardir"], "client_yaml/catalog")
      catalogfile = File.join(catalogdir, "#{node_name}.yaml")
      template = File.read("#{fixture_dir}/catalog.yaml.erb")
      renderer = ERB.new(template)
      catalog = renderer.result(binding)

      agent.mkdir_p(catalogdir)
      create_remote_file(agent, catalogfile, catalog, mkdirs: true)
    end

    step "run agents again, verify they use cached catalog" do
      # can't use --test, because that will set usecacheonfailure=false
      # We use a server that the agent can't possibly talk to in order
      # to guarantee that no communication can take place.
      on(agent, puppet("agent --onetime --no-daemonize --verbose",
                       "--server puppet.example.com --verbose")) do |result|
        assert_match(/Using cached catalog/, result.stdout)
      end
    end
  end
end
