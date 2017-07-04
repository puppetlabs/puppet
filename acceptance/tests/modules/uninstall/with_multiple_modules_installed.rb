test_name "puppet module uninstall (with multiple modules installed)"

tag 'audit:low',       # Module management via pmt is not the primary support workflow
    'audit:acceptance',
    'audit:refactor'   # Master is not required for this test. Replace with agents.each
                       # Wrap steps in blocks in accordance with Beaker style guide

if master.is_pe?
  skip_test
end

step 'Setup'
testdir = master.tmpdir('unistallmultiple')

stub_forge_on(master)

teardown do
  on master, "rm -rf #{master['distmoduledir']}/java"
  on master, "rm -rf #{master['distmoduledir']}/stdlub"
end

environmentpath = "#{testdir}/environments"

apply_manifest_on(master, %Q{
  File {
    ensure => directory,
    owner => #{master.puppet['user']},
    group => #{master.puppet['group']},
    mode => "0750",
  }
  file {
    [
      '#{environmentpath}',
      '#{environmentpath}/production',
    ]:
  }
})

master_opts = {
  'main' => {
    'environmentpath' => environmentpath,
    'basemodulepath' => "#{master['sitemoduledir']}:#{master['distmoduledir']}",
  }
}

with_puppet_running_on master, master_opts, testdir do
  on master, puppet("module install pmtacceptance-java --version 1.6.0 --modulepath #{master['distmoduledir']}")
  on master, puppet("module install pmtacceptance-java --version 1.7.0 --modulepath #{environmentpath}/production/modules")
  on master, puppet("module list --modulepath #{master['distmoduledir']}") do
    pattern = Regexp.new([
      "#{master['distmoduledir']}",
      "├── pmtacceptance-java \\(.*v1.6.0.*\\)",
      "└── pmtacceptance-stdlub \\(.*v1.0.0.*\\)"
    ].join("\n"))
    assert_match(pattern, result.output)
  end

  on master, puppet("module list --modulepath #{environmentpath}/production/modules") do
    pattern = Regexp.new([
      "#{environmentpath}/production/modules",
      "├── pmtacceptance-java \\(.*v1.7.0.*\\)",
      "└── pmtacceptance-stdlub \\(.*v1.0.0.*\\)",
    ].join("\n"))
    assert_match(pattern, result.output)
  end

  step "Try to uninstall a module that exists in multiple locations in the module path"
  on master, puppet("module uninstall pmtacceptance-java"), :acceptable_exit_codes => [1] do
    pattern = Regexp.new([
      ".*Notice: Preparing to uninstall 'pmtacceptance-java' .*",
      ".*Error: Could not uninstall module 'pmtacceptance-java'",
      "  Module 'pmtacceptance-java' appears multiple places in the module path",
      "    'pmtacceptance-java' \\(v1.7.0\\) was found in #{environmentpath}/production/modules",
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
