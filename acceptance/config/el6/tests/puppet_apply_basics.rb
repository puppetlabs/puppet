# Ported from a collection of small spec tests in acceptance.
#
# Unified into a single file because they are literally one-line tests!

test_name "Trivial puppet tests"

step "check that puppet apply displays notices"
agents.each do |host|
  apply_manifest_on(host, "notice 'Hello World'") do
    assert_match(/Hello World/, stdout, "#{host}: missing notice!")
  end
end

step "verify help displays something for puppet master"
on master, puppet_master("--help") do
  assert_match(/puppet master/, stdout, "improper help output")
end
