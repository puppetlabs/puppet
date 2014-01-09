test_name "Can enumerate enviromnents via an HTTP endpoint"

def master_url_for(agent, path)
  master_port = on(agent, "puppet config print masterport --section agent").stdout.chomp
  master_host = on(agent, "puppet config print server --section agent").stdout.chomp
  "https://#{master_host}:#{master_port}#{path}"
end

with_puppet_running_on(master, {}) do
  agents.each do |agent|
    on agent, "curl -ksv #{master_url_for(agent, '/v2/environments')}", :acceptable_exit_codes => [0,7] do
      assert_match(/< HTTP\/1\.\d 403/, stderr)
    end
  end
end
