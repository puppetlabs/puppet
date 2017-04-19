test_name "C99978: Agent parses a JSON catalog"
tag 'risk:medium'

require 'json'

step "Refresh the catalog" do
  on(agents, puppet("agent --test --server #{master}"))
end

step "Agent parses a JSON catalog" do
  agents.each do |agent|
    # Is it there?
    json_catalog = File.join(agent.puppet['client_datadir'], 'catalog',
                             "#{agent.puppet['certname']}.json")
    on(agent, "[[ -f #{json_catalog} ]]", {:acceptable_exit_codes => [0]})

    # Can we read it?
    rc = on(agent, "cat #{json_catalog}", {:acceptable_exit_codes => [0]})

    # Can we parse it
    begin
      json_content = JSON.parse(rc.stdout)
    rescue => e
      fail_test "Catalog data not in JSON-formatted catalog.\n" +
                "JSON parser threw the following exception:\n#{e.message}\n"
    end

    # Can the agent parse it
    on(agent, puppet("catalog find --terminus json --server #{master}"))
  end
end
