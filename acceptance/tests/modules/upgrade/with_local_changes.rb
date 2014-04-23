test_name "puppet module upgrade (with local changes)"

step 'Setup'

stub_forge_on(master)
on master, "mkdir -p #{master['distmoduledir']}"

teardown do
  on master, "rm -rf #{master['distmoduledir']}/java"
  on master, "rm -rf #{master['distmoduledir']}/stdlub"
end

on master, puppet("module install pmtacceptance-java --version 1.6.0")
on master, puppet("module list --modulepath #{master['distmoduledir']}") do
  assert_equal <<-OUTPUT, stdout
#{master['distmoduledir']}
├── pmtacceptance-java (\e[0;36mv1.6.0\e[0m)
└── pmtacceptance-stdlub (\e[0;36mv1.0.0\e[0m)
  OUTPUT
end
apply_manifest_on master, <<-PP
  file {
    '#{master['distmoduledir']}/java/README': content => "I CHANGE MY READMES";
    '#{master['distmoduledir']}/java/NEWFILE': content => "I don't exist.'";
  }
PP

step "Try to upgrade a module with local changes"
on master, puppet("module upgrade pmtacceptance-java"), :acceptable_exit_codes => [1] do
  pattern = Regexp.new([
    %Q{.*Notice: Preparing to upgrade 'pmtacceptance-java' ....*},
    %Q{.*Notice: Found 'pmtacceptance-java' \\(.*v1.6.0.*\\) in #{master['distmoduledir']} ....*},
    %Q{.*Error: Could not upgrade module 'pmtacceptance-java' \\(v1.6.0 -> latest\\)},
    %Q{  Installed module has had changes made locally},
    %Q{    Use `puppet module upgrade --force` to upgrade this module anyway.*},
  ].join("\n"), Regexp::MULTILINE)
  assert_match(pattern, result.output)
end
on master, %{[[ "$(cat #{master['distmoduledir']}/java/README)" == "I CHANGE MY READMES" ]]}
on master, "[ -f #{master['distmoduledir']}/java/NEWFILE ]"

step "Upgrade a module with local changes with --force"
on master, puppet("module upgrade pmtacceptance-java --force") do
  assert_equal <<-OUTPUT, stdout
\e[mNotice: Preparing to upgrade 'pmtacceptance-java' ...\e[0m
\e[mNotice: Found 'pmtacceptance-java' (\e[0;36mv1.6.0\e[m) in #{master['distmoduledir']} ...\e[0m
\e[mNotice: Downloading from https://forgeapi.puppetlabs.com ...\e[0m
\e[mNotice: Upgrading -- do not interrupt ...\e[0m
#{master['distmoduledir']}
└── pmtacceptance-java (\e[0;36mv1.6.0 -> v1.7.1\e[0m)
  OUTPUT
end
on master, %{[[ "$(cat #{master['distmoduledir']}/java/README)" != "I CHANGE MY READMES" ]]}
on master, "[ ! -f #{master['distmoduledir']}/java/NEWFILE ]"
