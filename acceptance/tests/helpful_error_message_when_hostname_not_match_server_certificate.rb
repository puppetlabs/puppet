test_name "generate a helpful error message when hostname doesn't match server certificate"

skip_test( 'Changing certnames of the master will break PE/Passenger installations' ) if master.is_using_passenger?

certname = "foobar_not_my_hostname"
dns_alt_names = "one_cert,two_cert,red_cert,blue_cert"

# The DNS names in the certificate's Subject Alternative Name extension
# may appear in any order so sort the list of names alphabetically before
# comparison.
expected_sorted_dns_alt_names = "DNS:" +
    dns_alt_names.split(",").push(certname).sort().join(", DNS:")

# Start the master with a certname not matching its hostname
master_opts = {
  'master' => {
    'certname' => certname,
    'dns_alt_names' => dns_alt_names
  }
}

with_puppet_running_on master, master_opts do
  run_agent_on(agents, "--test --server #{master}", :acceptable_exit_codes => (1..255)) do
    msg = "Server hostname '" +
        Regexp.escape(master) +
        "' did not match server certificate; expected one of " +
        Regexp.escape(certname) +
        ', (.*)$'

    exp = Regexp.new (msg)

    match_result = exp.match(stderr)

    assert(match_result, "Expected " + msg + " to match '" + stderr + "'")

    # Sort the expected DNS names in alphabetical order before comparison.
    # The names extracted from the shell output might contain color output
    # characters at the end (\e[0m), so strip those off before sorting.
    actual_sorted_dns_alt_names = match_result[1].sub(/\e\[0m$/,'').
      split(", ").sort().join(", ")

    assert_equal(expected_sorted_dns_alt_names, actual_sorted_dns_alt_names,
        "Unexpected DNS alt names found in server certificate")
  end
end
