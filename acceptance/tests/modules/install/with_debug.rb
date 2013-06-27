test_name "puppet module install (with debug)"

step 'Setup'

stub_forge_on(master)
on master, "mkdir -p #{master['distmoduledir']}"
on master, "mkdir -p #{master['sitemoduledir']}"

teardown do
  on master, "rm -rf #{master['distmoduledir']}/*"
end

step "Install a module with debug output"
on master, puppet("module install pmtacceptance-java --debug") do
  assert_match(/Debug: Executing/, stdout,
          "No 'Debug' output displayed!")
end
