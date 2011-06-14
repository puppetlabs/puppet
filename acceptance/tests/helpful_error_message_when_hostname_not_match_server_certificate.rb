test_name "generate a helpful error message when hostname doesn't match server certificate"

step "Clear any existing SSL directories"
on(hosts, "rm -r #{config['puppetpath']}/ssl")

# Start the master with a certname not matching its hostname
with_master_running_on(master, "--certname foobar_not_my_hostname --certdnsnames one_cert:two_cert:red_cert:blue_cert --autosign true") do
  run_agent_on(agents, "--no-daemonize --verbose --onetime --server #{master}", :acceptable_exit_codes => (1..255)) do
    msg = "Server hostname '#{master}' did not match server certificate; expected one of foobar_not_my_hostname, one_cert, two_cert, red_cert, blue_cert"
    assert_match(msg, stdout)
  end
end
