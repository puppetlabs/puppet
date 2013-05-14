test_name "puppet module install (with existing module directory)"

step 'Setup'

stub_forge_on(master)

teardown do
  on master, "rm -rf #{master['distmoduledir']}/apache"
  on master, "rm -rf #{master['distmoduledir']}/nginx"
end

apply_manifest_on master, <<-PP
file {
  [
    '#{master['distmoduledir']}/nginx',
    '#{master['distmoduledir']}/apache',
  ]: ensure => directory;
  '#{master['distmoduledir']}/nginx/metadata.json':
    content => '{
      "name": "notpmtacceptance/nginx",
      "version": "0.0.3",
      "source": "",
      "author": "notpmtacceptance",
      "license": "MIT",
      "dependencies": []
    }';
  [
    '#{master['distmoduledir']}/nginx/extra.json',
    '#{master['distmoduledir']}/apache/extra.json',
  ]: content => '';
}
PP

step "Try to install an module with a name collision"
on master, puppet("module install pmtacceptance-nginx"), :acceptable_exit_codes => [1] do
  assert_output <<-OUTPUT
    STDOUT> \e[mNotice: Preparing to install into #{master['distmoduledir']} ...\e[0m
    STDOUT> \e[mNotice: Downloading from https://forge.puppetlabs.com ...\e[0m
    STDERR> \e[1;31mError: Could not install module 'pmtacceptance-nginx' (latest: v0.0.1)
    STDERR>   Installation would overwrite #{master['distmoduledir']}/nginx
    STDERR>     Currently, 'notpmtacceptance-nginx' (v0.0.3) is installed to that directory
    STDERR>     Use `puppet module install --dir <DIR>` to install modules elsewhere
    STDERR>     Use `puppet module install --force` to install this module anyway\e[0m
  OUTPUT
end
on master, "[ -f #{master['distmoduledir']}/nginx/extra.json ]"

step "Try to install an module with a path collision"
on master, puppet("module install pmtacceptance-apache"), :acceptable_exit_codes => [1] do
  assert_output <<-OUTPUT
    STDOUT> \e[mNotice: Preparing to install into #{master['distmoduledir']} ...\e[0m
    STDOUT> \e[mNotice: Downloading from https://forge.puppetlabs.com ...\e[0m
    STDERR> \e[1;31mError: Could not install module 'pmtacceptance-apache' (latest: v0.0.1)
    STDERR>   Installation would overwrite #{master['distmoduledir']}/apache
    STDERR>     Use `puppet module install --dir <DIR>` to install modules elsewhere
    STDERR>     Use `puppet module install --force` to install this module anyway\e[0m
  OUTPUT
end
on master, "[ -f #{master['distmoduledir']}/apache/extra.json ]"

step "Try to install an module with a dependency that has collides"
on master, puppet("module install pmtacceptance-php --version 0.0.1"), :acceptable_exit_codes => [1] do
  assert_output <<-OUTPUT
    STDOUT> \e[mNotice: Preparing to install into #{master['distmoduledir']} ...\e[0m
    STDOUT> \e[mNotice: Downloading from https://forge.puppetlabs.com ...\e[0m
    STDERR> \e[1;31mError: Could not install module 'pmtacceptance-php' (v0.0.1)
    STDERR>   Dependency 'pmtacceptance-apache' (v0.0.1) would overwrite #{master['distmoduledir']}/apache
    STDERR>     Use `puppet module install --dir <DIR>` to install modules elsewhere
    STDERR>     Use `puppet module install --ignore-dependencies` to install only this module\e[0m
  OUTPUT
end
on master, "[ -f #{master['distmoduledir']}/apache/extra.json ]"

step "Install an module with a name collision by using --force"
on master, puppet("module install pmtacceptance-nginx --force"), :acceptable_exit_codes => [0] do
  assert_output <<-OUTPUT
    \e[mNotice: Preparing to install into #{master['distmoduledir']} ...\e[0m
    \e[mNotice: Downloading from https://forge.puppetlabs.com ...\e[0m
    \e[mNotice: Installing -- do not interrupt ...\e[0m
    #{master['distmoduledir']}
    └── pmtacceptance-nginx (\e[0;36mv0.0.1\e[0m)
  OUTPUT
end
on master, "[ ! -f #{master['distmoduledir']}/nginx/extra.json ]"

step "Install an module with a name collision by using --force"
on master, puppet("module install pmtacceptance-apache --force"), :acceptable_exit_codes => [0] do
  assert_output <<-OUTPUT
    \e[mNotice: Preparing to install into #{master['distmoduledir']} ...\e[0m
    \e[mNotice: Downloading from https://forge.puppetlabs.com ...\e[0m
    \e[mNotice: Installing -- do not interrupt ...\e[0m
    #{master['distmoduledir']}
    └── pmtacceptance-apache (\e[0;36mv0.0.1\e[0m)
  OUTPUT
end
on master, "[ ! -f #{master['distmoduledir']}/apache/extra.json ]"

