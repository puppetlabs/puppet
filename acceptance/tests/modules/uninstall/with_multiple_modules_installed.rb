test_name "puppet module uninstall (with multiple modules installed)"

step 'Setup'
testdir = master.tmpdir('unistallmultiple')

stub_forge_on(master)

teardown do
  on master, "rm -rf #{master['distmoduledir']}/java"
  on master, "rm -rf #{master['distmoduledir']}/stdlub"
end

on master, "mkdir -p #{testdir}/modules"
on master, "chown -R #{master['user']}:#{master['group']} #{testdir}"

master_opts = {
  'main' => {
    'modulepath' => "#{testdir}/modules:#{master['sitemoduledir']}:#{master['distmoduledir']}"
  }
}

with_puppet_running_on master, master_opts, testdir do
  on master, puppet("module install pmtacceptance-java --version 1.6.0 --modulepath #{master['distmoduledir']}")
  on master, puppet("module install pmtacceptance-java --version 1.7.0 --modulepath #{testdir}/modules")
  on master, puppet("module list --modulepath #{master['distmoduledir']}") do
    pattern = Regexp.new([
      "#{master['distmoduledir']}",
      "├── pmtacceptance-java \\(.*v1.6.0.*\\)",
      "└── pmtacceptance-stdlub \\(.*v1.0.0.*\\)"
    ].join("\n"))
    assert_match(pattern, result.output)
  end

  on master, puppet("module list --modulepath #{testdir}/modules") do
    pattern = Regexp.new([
      "#{testdir}/modules",
      "├── pmtacceptance-java \\(.*v1.7.0.*\\)",
      "└── pmtacceptance-stdlub \\(.*v1.0.0.*\\)",
    ].join("\n"))
    assert_match(pattern, result.output)
  end

  step "Try to uninstall a module that exists multiple locations in the module path"
  on master, puppet("module uninstall pmtacceptance-java"), :acceptable_exit_codes => [1] do
    pattern = Regexp.new([
      ".*Notice: Preparing to uninstall 'pmtacceptance-java' .*",
      ".*Error: Could not uninstall module 'pmtacceptance-java'",
      "  Module 'pmtacceptance-java' appears multiple places in the module path",
      "    'pmtacceptance-java' \\(v1.7.0\\) was found in #{testdir}/modules",
      "    'pmtacceptance-java' \\(v1.6.0\\) was found in #{master['distmoduledir']}",
      "    Use the `--modulepath` option to limit the search to specific directories.*"
    ].join("\n"), Regexp::MULTILINE)
    assert_match(pattern, result.output)
  end

  step "Uninstall a module that exists multiple locations by restricting the --modulepath"
  on master, puppet("module uninstall pmtacceptance-java --modulepath #{master['distmoduledir']}") do
    pattern = Regexp.new([
      ".*Notice: Preparing to uninstall 'pmtacceptance-java' .*",
      "Removed 'pmtacceptance-java' \\(.*v1.6.0.*\\) from #{master['distmoduledir']}"
    ].join("\n"), Regexp::MULTILINE)
    assert_match(pattern, result.output)
  end
end
