test_name "puppet module upgrade (to installed version)"

step 'Setup'
on master, "mkdir -p #{master['distmoduledir']}"

stub_forge_on(master)

teardown do
  on master, "rm -rf #{master['distmoduledir']}/java"
  on master, "rm -rf #{master['distmoduledir']}/stdlib"
end

on master, puppet("module install pmtacceptance-java --version 1.6.0")
on master, puppet("module list --modulepath #{master['distmoduledir']}") do
  assert_equal <<-OUTPUT, stdout
#{master['distmoduledir']}
├── pmtacceptance-java (\e[0;36mv1.6.0\e[0m)
└── pmtacceptance-stdlib (\e[0;36mv1.0.0\e[0m)
  OUTPUT
end

step "Try to upgrade a module to the current version"
on master, puppet("module upgrade pmtacceptance-java --version 1.6.x"), :acceptable_exit_codes => [0] do
  pattern = Regexp.new([
    %Q{.*Notice: Preparing to upgrade 'pmtacceptance-java' ....*},
    %Q{.*Notice: Found 'pmtacceptance-java' \\(.*v1.6.0.*\\) in #{master['distmoduledir']} ....*},
    %Q{.*Notice: Downloading from https://forge.puppetlabs.com ....*},
    %Q{.*Error: Could not upgrade module 'pmtacceptance-java' \\(v1.6.0 -> v1.6.x\\)},
    %Q{  The installed version is already the best fit for the current dependencies},
    %Q{    You specified 'pmtacceptance-java' \\(v1.6.x\\)},
    %Q{    Use `puppet module install --force` to re-install this module.*},
  ].join("\n"), Regexp::MULTILINE)
  assert_match(pattern, result.output)
end

step "Upgrade a module to the current version with --force"
on master, puppet("module upgrade pmtacceptance-java --version 1.6.x --force") do
  assert_equal <<-OUTPUT, stdout
\e[mNotice: Preparing to upgrade 'pmtacceptance-java' ...\e[0m
\e[mNotice: Found 'pmtacceptance-java' (\e[0;36mv1.6.0\e[m) in #{master['distmoduledir']} ...\e[0m
\e[mNotice: Downloading from https://forge.puppetlabs.com ...\e[0m
\e[mNotice: Upgrading -- do not interrupt ...\e[0m
#{master['distmoduledir']}
└── pmtacceptance-java (\e[0;36mv1.6.0 -> v1.6.0\e[0m)
  OUTPUT
end

step "Upgrade to the latest version"
on master, puppet("module upgrade pmtacceptance-java") do
  assert_equal <<-OUTPUT, stdout
\e[mNotice: Preparing to upgrade 'pmtacceptance-java' ...\e[0m
\e[mNotice: Found 'pmtacceptance-java' (\e[0;36mv1.6.0\e[m) in #{master['distmoduledir']} ...\e[0m
\e[mNotice: Downloading from https://forge.puppetlabs.com ...\e[0m
\e[mNotice: Upgrading -- do not interrupt ...\e[0m
#{master['distmoduledir']}
└── pmtacceptance-java (\e[0;36mv1.6.0 -> v1.7.1\e[0m)
  OUTPUT
end

step "Try to upgrade a module to the latest version with the latest version installed"
on master, puppet("module upgrade pmtacceptance-java"), :acceptable_exit_codes => [0] do
  pattern = Regexp.new([
    %Q{.*Notice: Preparing to upgrade 'pmtacceptance-java' ....*},
    %Q{.*Notice: Found 'pmtacceptance-java' \\(.*v1.7.1.*\\) in #{master['distmoduledir']} ....*},
    %Q{.*Notice: Downloading from https://forge.puppetlabs.com ....*},
    %Q{.*Error: Could not upgrade module 'pmtacceptance-java' \\(v1.7.1 -> latest: v1.7.1\\)},
    %Q{  The installed version is already the latest version},
    %Q{    Use `puppet module install --force` to re-install this module.*},
  ].join("\n"), Regexp::MULTILINE)
  assert_match(pattern, result.output)
end

step "Upgrade a module to the latest version with --force"
on master, puppet("module upgrade pmtacceptance-java --force") do
  assert_equal <<-OUTPUT, stdout
\e[mNotice: Preparing to upgrade 'pmtacceptance-java' ...\e[0m
\e[mNotice: Found 'pmtacceptance-java' (\e[0;36mv1.7.1\e[m) in #{master['distmoduledir']} ...\e[0m
\e[mNotice: Downloading from https://forge.puppetlabs.com ...\e[0m
\e[mNotice: Upgrading -- do not interrupt ...\e[0m
#{master['distmoduledir']}
└── pmtacceptance-java (\e[0;36mv1.7.1 -> v1.7.1\e[0m)
  OUTPUT
end
