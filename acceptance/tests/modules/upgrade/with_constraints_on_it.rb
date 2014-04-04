test_name "puppet module upgrade (with constraints on it)"

step 'Setup'

stub_forge_on(master)

teardown do
  on master, "rm -rf #{master['distmoduledir']}/apollo"
  on master, "rm -rf #{master['distmoduledir']}/java"
  on master, "rm -rf #{master['distmoduledir']}/stdlib"
end

on master, puppet("module install pmtacceptance-java --version 1.7.0")
on master, puppet("module install pmtacceptance-apollo")
on master, puppet("module list --modulepath #{master['distmoduledir']}") do
  assert_equal <<-OUTPUT, stdout
#{master['distmoduledir']}
├── pmtacceptance-apollo (\e[0;36mv0.0.1\e[0m)
├── pmtacceptance-java (\e[0;36mv1.7.0\e[0m)
└── pmtacceptance-stdlib (\e[0;36mv1.0.0\e[0m)
  OUTPUT
end


step "Upgrade a version-constrained module that has an upgrade"
on master, puppet("module upgrade pmtacceptance-java") do
  assert_equal <<-OUTPUT, stdout
\e[mNotice: Preparing to upgrade 'pmtacceptance-java' ...\e[0m
\e[mNotice: Found 'pmtacceptance-java' (\e[0;36mv1.7.0\e[m) in #{master['distmoduledir']} ...\e[0m
\e[mNotice: Downloading from https://forge.puppetlabs.com ...\e[0m
\e[mNotice: Upgrading -- do not interrupt ...\e[0m
#{master['distmoduledir']}
└── pmtacceptance-java (\e[0;36mv1.7.0 -> v1.7.1\e[0m)
  OUTPUT
end

step "Try to upgrade a version-constrained module that has no upgrade"
on master, puppet("module upgrade pmtacceptance-stdlib"), :acceptable_exit_codes => [0] do
  pattern = Regexp.new([
    %Q{.*Notice: Preparing to upgrade 'pmtacceptance-stdlib' ....*},
    %Q{.*Notice: Found 'pmtacceptance-stdlib' \\(.*v1.0.0.*\\) in #{master['distmoduledir']} ....*},
    %Q{.*Notice: Downloading from https://forge.puppetlabs.com ....*},
    %Q{.*Error: Could not upgrade module 'pmtacceptance-stdlib' \\(v1.0.0 -> best: v1.0.0\\)},
    %Q{  The installed version is already the best fit for the current dependencies},
    %Q{    'pmtacceptance-apollo' \\(v0.0.1\\) requires 'pmtacceptance-stdlib' \\(>= 1.0.0\\)},
    %Q{    'pmtacceptance-java' \\(v1.7.1\\) requires 'pmtacceptance-stdlib' \\(v1.0.0\\)},
    %Q{    Use `puppet module install --force` to re-install this module.*},
  ].join("\n"), Regexp::MULTILINE)
  assert_match(pattern, result.output)
end
