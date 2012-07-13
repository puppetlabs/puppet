test_name "generate a helpful error message when hostname doesn't match server certificate"

# Start the master with a certname not matching its hostname
with_master_running_on(master, "--certname foobar_not_my_hostname --dns_alt_names one_cert,two_cert,red_cert,blue_cert --autosign true") do
  run_agent_on(agents, "--test --server #{master}", :acceptable_exit_codes => (1..255)) do
    msg = "Server hostname '#{master}' did not match server certificate; expected one of foobar_not_my_hostname, DNS:blue_cert, DNS:foobar_not_my_hostname, DNS:one_cert, DNS:red_cert, DNS:two_cert"
    assert_match(msg, stderr)
  end
end
