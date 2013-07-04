test_name "puppet module install (with existing module directory)"

module_author = "pmtacceptance"
module_name   = "nginx"
module_dependencies   = [""]

teardown do
  on master, "rm -rf #{master['distmoduledir']}/*"
  agents.each do |agent|
    on agent, "rm -rf #{agent['distmoduledir']}/*"
  end
  on master, "rm -rf #{master['sitemoduledir']}/#{module_name}"
  module_dependencies.each do |dependency|
    on master, "rm -rf #{master['sitemoduledir']}/#{dependency}"
  end
end

step 'Setup'

stub_forge_on(master)

apply_manifest_on master, <<-PP
file {
  [
    '#{master['distmoduledir']}/#{module_name}',
    '#{master['distmoduledir']}/apache',
  ]: ensure => directory;
  '#{master['distmoduledir']}/#{module_name}/metadata.json':
    content => '{
      "name": "not#{module_author}/#{module_name}",
      "version": "0.0.3",
      "source": "",
      "author": "not#{module_author}",
      "license": "MIT",
      "dependencies": []
    }';
  [
    '#{master['distmoduledir']}/#{module_name}/extra.json',
    '#{master['distmoduledir']}/apache/extra.json',
  ]: content => '';
}
PP

step "Try to install a module with a name collision"
module_name   = "nginx"
on master, puppet("module install #{module_author}-#{module_name}"), :acceptable_exit_codes => [1] do
  assert_output <<-OUTPUT
    STDOUT> \e[mNotice: Preparing to install into #{master['distmoduledir']} ...\e[0m
    STDOUT> \e[mNotice: Downloading from https://forge.puppetlabs.com ...\e[0m
    STDERR> \e[1;31mError: Could not install module '#{module_author}-#{module_name}' (latest: v0.0.1)
    STDERR>   Installation would overwrite #{master['distmoduledir']}/#{module_name}
    STDERR>     Currently, 'not#{module_author}-#{module_name}' (v0.0.3) is installed to that directory
    STDERR>     Use `puppet module install --target-dir <DIR>` to install modules elsewhere
    STDERR>     Use `puppet module install --force` to install this module anyway\e[0m
  OUTPUT
end
on master, "[ -f #{master['distmoduledir']}/#{module_name}/extra.json ]"

step "Try to install a module with a path collision"
module_name   = "apache"
on master, puppet("module install #{module_author}-#{module_name}"), :acceptable_exit_codes => [1] do
  assert_output <<-OUTPUT
    STDOUT> \e[mNotice: Preparing to install into #{master['distmoduledir']} ...\e[0m
    STDOUT> \e[mNotice: Downloading from https://forge.puppetlabs.com ...\e[0m
    STDERR> \e[1;31mError: Could not install module '#{module_author}-#{module_name}' (latest: v0.0.1)
    STDERR>   Installation would overwrite #{master['distmoduledir']}/#{module_name}
    STDERR>     Use `puppet module install --target-dir <DIR>` to install modules elsewhere
    STDERR>     Use `puppet module install --force` to install this module anyway\e[0m
  OUTPUT
end
on master, "[ -f #{master['distmoduledir']}/#{module_name}/extra.json ]"

step "Try to install a module with a dependency that has collides"
module_name   = "php"
on master, puppet("module install #{module_author}-#{module_name} --version 0.0.1"), :acceptable_exit_codes => [1] do
  assert_output <<-OUTPUT
    STDOUT> \e[mNotice: Preparing to install into #{master['distmoduledir']} ...\e[0m
    STDOUT> \e[mNotice: Downloading from https://forge.puppetlabs.com ...\e[0m
    STDERR> \e[1;31mError: Could not install module '#{module_author}-#{module_name}' (v0.0.1)
    STDERR>   Dependency '#{module_author}-apache' (v0.0.1) would overwrite #{master['distmoduledir']}/apache
    STDERR>     Use `puppet module install --target-dir <DIR>` to install modules elsewhere
    STDERR>     Use `puppet module install --ignore-dependencies` to install only this module\e[0m
  OUTPUT
end
on master, "[ -f #{master['distmoduledir']}/apache/extra.json ]"

step "Install a module with a name collision by using --force"
module_name   = "nginx"
on master, puppet("module install #{module_author}-#{module_name} --force"), :acceptable_exit_codes => [0] do
  assert_output <<-OUTPUT
    \e[mNotice: Preparing to install into #{master['distmoduledir']} ...\e[0m
    \e[mNotice: Downloading from https://forge.puppetlabs.com ...\e[0m
    \e[mNotice: Installing -- do not interrupt ...\e[0m
    #{master['distmoduledir']}
    └── #{module_author}-#{module_name} (\e[0;36mv0.0.1\e[0m)
  OUTPUT
end
on master, "[ ! -f #{master['distmoduledir']}/#{module_name}/extra.json ]"

step "Install an module with a name collision by using --force"
module_name   = "apache"
on master, puppet("module install #{module_author}-#{module_name} --force"), :acceptable_exit_codes => [0] do
  assert_output <<-OUTPUT
    \e[mNotice: Preparing to install into #{master['distmoduledir']} ...\e[0m
    \e[mNotice: Downloading from https://forge.puppetlabs.com ...\e[0m
    \e[mNotice: Installing -- do not interrupt ...\e[0m
    #{master['distmoduledir']}
    └── #{module_author}-#{module_name} (\e[0;36mv0.0.1\e[0m)
  OUTPUT
end
on master, "[ ! -f #{master['distmoduledir']}/#{module_name}/extra.json ]"

