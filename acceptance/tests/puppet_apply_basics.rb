# Ported from a collection of small spec tests in acceptance.
#
# Unified into a single file because they are literally one-line tests!

test_name "Trivial puppet tests"

step "check that puppet apply displays notices"
apply_manifest_on(agents, "notice 'Hello World'") do
  stdout =~ /notice:.*Hello World/ or fail_test("missing notice!")
end

step "verify help displays something for puppet master"
on master, puppet_master("--help") do
  stdout =~ /puppet master/ or fail_test("improper help output")
end
