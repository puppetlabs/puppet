test_name "puppet module uninstall (with multiple modules installed)"

step 'Setup'

stub_forge_on(master)

teardown do
  on master, "rm -rf #{master['distmoduledir']}/java"
  on master, "rm -rf #{master['distmoduledir']}/stdlib"
  on master, "rm -rf #{master['sitemoduledir']}/java"
end

on master, puppet("module install pmtacceptance-java --version 1.6.0 --modulepath #{master['distmoduledir']}")
on master, puppet("module install pmtacceptance-java --version 1.7.0 --modulepath #{master['sitemoduledir']}")
on master, puppet("module list") do
  assert_output <<-OUTPUT
    #{master['distmoduledir']}
    ├── pmtacceptance-java (\e[0;36mv1.6.0\e[0m)
    └── pmtacceptance-stdlib (\e[0;36mv1.0.0\e[0m)
    #{master['sitemoduledir']}
    ├── pmtacceptance-java (\e[0;36mv1.7.0\e[0m)
    └── pmtacceptance-stdlib (\e[0;36mv1.0.0\e[0m)
  OUTPUT
end

step "Try to uninstall a module that exists multiple locations in the module path"
on master, puppet("module uninstall pmtacceptance-java"), :acceptable_exit_codes => [1] do
  assert_output <<-OUTPUT
    STDOUT> \e[mNotice: Preparing to uninstall 'pmtacceptance-java' ...\e[0m
    STDERR> \e[1;31mError: Could not uninstall module 'pmtacceptance-java'
    STDERR>   Module 'pmtacceptance-java' appears multiple places in the module path
    STDERR>     'pmtacceptance-java' (v1.6.0) was found in #{master['distmoduledir']}
    STDERR>     'pmtacceptance-java' (v1.7.0) was found in #{master['sitemoduledir']}
    STDERR>     Use the `--modulepath` option to limit the search to specific directories\e[0m
  OUTPUT
end

step "Uninstall a module that exists multiple locations by restricting the --modulepath"
on master, puppet("module uninstall pmtacceptance-java --modulepath #{master['distmoduledir']}") do
  assert_output <<-OUTPUT
    \e[mNotice: Preparing to uninstall 'pmtacceptance-java' ...\e[0m
    Removed 'pmtacceptance-java' (\e[0;36mv1.6.0\e[0m) from #{master['distmoduledir']}
  OUTPUT
end
