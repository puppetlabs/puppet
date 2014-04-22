test_name "puppet module upgrade (that was installed twice)"
skip_test "This test does not seem to properly respect the given modulepath"

step 'Setup'

stub_forge_on(master)
testdir = master.tmpdir('upgrademultimods')

teardown do
  on master, "rm -rf #{master['distmoduledir']}/java"
  on master, "rm -rf #{master['distmoduledir']}/stdlub"
  on master, "rm -rf #{testdir}/modules/java"
  on master, "rm -rf #{testdir}/modules/stdlub"
end

master_opts = {
  'main' => {
    'modulepath' => "#{master['distmoduledir']}:#{testdir}/modules"
  }
}



with_puppet_running_on master, master_opts, testdir do
  on master, puppet("module install pmtacceptance-java --version 1.6.0 --modulepath #{master['distmoduledir']}")
  on master, puppet("module install pmtacceptance-java --version 1.7.0 --modulepath #{testdir}/modules")
  on master, puppet("module list") do
    pattern = Regexp.new([
      "#{master['distmoduledir']}",
      "├── pmtacceptance-java \\(.*v1.6.0\e.*\\)",
      "└── pmtacceptance-stdlub \\(.*v1.0.0.*\\)",
      "#{testdir}/modules",
      "├── pmtacceptance-java \\(.*v1.7.0.*\\)",
      "└── pmtacceptance-stdlub \\(.*v1.0.0.*\\)",
    ].join("\n"))
    assert_match(pattern, result.output)
  end

  step "Try to upgrade a module that exists multiple locations in the module path"
  on master, puppet("module upgrade pmtacceptance-java"), :acceptable_exit_codes => [1] do
    pattern = Regexp.new([
      ".*Notice: Preparing to upgrade 'pmtacceptance-java' .*",
      ".*Error: Could not upgrade module 'pmtacceptance-java'",
      "  Module 'pmtacceptance-java' appears multiple places in the module path",
      "    'pmtacceptance-java' \\(v1.6.0\\) was found in #{master['distmoduledir']}",
      "    'pmtacceptance-java' \\(v1.7.0\\) was found in #{testdir}/modules",
      "    Use the `--modulepath` option to limit the search to specific directories",
    ].join("\n"), Regexp::MULTILINE)
    assert_match(pattern, result.output)
  end

  step "Upgrade a module that exists multiple locations by restricting the --modulepath"
  on master, puppet("module upgrade pmtacceptance-java --modulepath #{master['distmoduledir']}") do
    pattern = Regexp.new([
      ".*Notice: Preparing to upgrade 'pmtacceptance-java' .*",
      ".*Notice: Found 'pmtacceptance-java' \\(.*v1.6.0.*\\) in #{master['distmoduledir']} .*",
      ".*Notice: Downloading from https://forgeapi.puppetlabs.com .*",
      ".*Notice: Upgrading -- do not interrupt .*",
      "#{master['distmoduledir']}",
      "└── pmtacceptance-java \\(.*v1.6.0 -> v1.7.1.*\\)",
    ].join("\n"), Regexp::MULTILINE)
    assert_match(pattern, result.output)
  end
end
