test_name "C99978: Agent parses a JSON catalog"

tag 'risk:medium',
    'audit:high',        # tests defined catalog format
    'audit:integration', # There is no OS specific risk here.
    'server',
    'catalog:json'

require 'puppet/acceptance/common_utils'
require 'json'

step "Agent parses a JSON catalog" do
  agents.each do |agent|
    # Path to a ruby binary
    ruby = Puppet::Acceptance::CommandUtils.ruby_command(agent)
  
    # Refresh the catalog
    on(agent, puppet("agent --test --server #{master}"))

    # The catalog file should be parseable JSON
    json_catalog = File.join(agent.puppet['client_datadir'], 'catalog',
                             "#{agent.puppet['certname']}.json")
    on(agent, "cat #{json_catalog} | #{ruby} -rjson -e 'JSON.parse(STDIN.read)'")

    # Can the agent parse it as JSON?
    on(agent, puppet("catalog find --terminus json --server #{master} > /dev/null"))
  end
end
