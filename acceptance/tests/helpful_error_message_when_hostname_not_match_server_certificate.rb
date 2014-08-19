test_name "generate a helpful error message when hostname doesn't match server certificate"

skip_test "Certs need to be signed with DNS Alt names." if @options[:is_jvm_puppet]
skip_test( 'Changing certnames of the master will break PE/Passenger installations' ) if master.is_using_passenger?

# Start the master with a certname not matching its hostname
master_opts = {
  'master' => {
    'certname' => 'foobar_not_my_hostname',
    'dns_alt_names' => 'one_cert,two_cert,red_cert,blue_cert'
  }
}
with_puppet_running_on master, master_opts do
  run_agent_on(agents, "--test --server #{master}", :acceptable_exit_codes => (1..255)) do
    msg = "Server hostname '#{master}' did not match server certificate; expected one of foobar_not_my_hostname, DNS:blue_cert, DNS:foobar_not_my_hostname, DNS:one_cert, DNS:red_cert, DNS:two_cert"
    assert_match(msg, stderr)
  end
end
