test_name "puppet module upgrade (with scattered dependencies)"

step 'Setup'

stub_forge_on(master)
testdir = master.tmpdir('scattereddeps')
on master, "mkdir -p #{master['distmoduledir']}"
on master, "mkdir -p #{master['sitemoduledir']}"
on master, "mkdir -p #{testdir}/modules"

teardown do
  on master, "rm -rf #{master['distmoduledir']}/java"
  on master, "rm -rf #{master['distmoduledir']}/postgresql"
end

master_opts = {
  'main' => {
    'modulepath' => "#{testdir}/modules:#{master['distmoduledir']}:#{master['sitemoduledir']}"
  }
}

with_puppet_running_on master, master_opts, testdir do
  on master, puppet("module install pmtacceptance-stdlib --version 0.0.2 --target-dir #{testdir}/modules")
  on master, puppet("module install pmtacceptance-java --version 1.6.0 --target-dir #{master['distmoduledir']} --ignore-dependencies")
  on master, puppet("module install pmtacceptance-postgresql --version 0.0.1 --target-dir #{master['distmoduledir']} --ignore-dependencies")
  on master, puppet("module list") do
    assert_match /pmtacceptance-java.*1\.6\.0/, stdout, 'Could not find pmtacceptance/java'
    assert_match /pmtacceptance-postgresql.*0\.0\.1/, stdout, 'Could not find pmtacceptance/postgresql'
    assert_match /pmtacceptance-stdlib.*0\.0\.2/, stdout, 'Could not find pmtacceptance/stdlib'
  end

  step "Upgrade a module that has a more recent version published"
  on master, puppet("module upgrade pmtacceptance-postgresql --version 0.0.2") do
    pattern = Regexp.new([
      ".*Notice: Preparing to upgrade 'pmtacceptance-postgresql' .*",
      ".*Notice: Found 'pmtacceptance-postgresql' \\(.*v0.0.1.*\\) in #{master['distmoduledir']} .*",
      ".*Notice: Downloading from https://forge.puppetlabs.com .*",
      ".*Notice: Upgrading -- do not interrupt .*",
      "#{master['distmoduledir']}",
      "└─┬ pmtacceptance-postgresql \\(.*v0.0.1 -> v0.0.2.*\\)",
      "  ├─┬ pmtacceptance-java \\(.*v1.6.0 -> v1.7.0.*\\)",
      "  │ └── pmtacceptance-stdlib \\(.*v0.0.2 -> v1.0.0.*\\) \\[#{testdir}/modules\\]",
      "  └── pmtacceptance-stdlib \\(.*v0.0.2 -> v1.0.0.*\\) \\[#{testdir}/modules\\]",
    ].join("\n"), Regexp::MULTILINE)
    assert_match(pattern, result.output)
  end
end
