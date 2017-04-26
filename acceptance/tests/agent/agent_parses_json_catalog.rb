test_name "C99978: Agent parses a JSON catalog"
tag 'risk:medium'

require 'json'

step "Refresh the catalog" do
  on(agents, puppet("agent --test --server #{master}"))
end

step "Agent parses a JSON catalog" do
  agents.each do |agent|
    # Is it there and can we read it?
    json_catalog = File.join(agent.puppet['client_datadir'], 'catalog',
                             "#{agent.puppet['certname']}.json")
    on(agent, "[[ -r #{json_catalog} ]]", {:acceptable_exit_codes => [0]})

    # Can the agent parse it as JSON?
    on(agent, puppet("catalog find --terminus json --server #{master} > /dev/null"))
  end
end
