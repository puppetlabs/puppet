test_name "Validate Sign Cert"

step "Master: Start Puppet Master"
with_master_running_on(master, "--certname #{master} --verbose") do
  hosts.each do |host|
    next if host['roles'].include? 'master'

    step "Agents: Run agent --test first time to gen CSR"
    on host, puppet_agent("--test --server #{master}"), :acceptable_exit_codes => [1]
  end

  # Sign all waiting certs
  step "Master: sign all certs"
  on master, puppet_cert("--sign --all"), :acceptable_exit_codes => [0,24]

  step "Agents: Run agent --test second time to obtain signed cert"
  on agents, puppet_agent("--test --server #{master}"), :acceptable_exit_codes => [0,2]
end

