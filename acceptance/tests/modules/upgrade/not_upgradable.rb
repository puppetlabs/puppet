test_name "puppet module upgrade (not upgradable)"

step 'Setup'

stub_forge_on(master)

apply_manifest_on master, <<-'MANIFEST1'
file { '/usr/share/puppet':
  ensure  => directory,
}
file { ['/etc/puppet/modules', '/usr/share/puppet/modules']:
  ensure  => directory,
  recurse => true,
  purge   => true,
  force   => true,
}
MANIFEST1
teardown do
  on master, "rm -rf /etc/puppet/modules"
  on master, "rm -rf /usr/share/puppet/modules"
end

apply_manifest_on master, <<-PP
  file {
    [
      '/etc/puppet/modules/nginx',
      '/etc/puppet/modules/unicorns',
    ]: ensure => directory;
    '/etc/puppet/modules/unicorns/metadata.json':
      content => '{
        "name": "notpmtacceptance/unicorns",
        "version": "0.0.3",
        "source": "",
        "author": "notpmtacceptance",
        "license": "MIT",
        "dependencies": []
      }';
  }
PP
on master, puppet("module install pmtacceptance-java --version 1.6.0")
on master, puppet("module list") do
  assert_output <<-OUTPUT
    /etc/puppet/modules
    ├── nginx (\e[0;36m???\e[0m)
    ├── notpmtacceptance-unicorns (\e[0;36mv0.0.3\e[0m)
    ├── pmtacceptance-java (\e[0;36mv1.6.0\e[0m)
    └── pmtacceptance-stdlib (\e[0;36mv1.0.0\e[0m)
    /usr/share/puppet/modules (no modules installed)
  OUTPUT
end

step "Try to upgrade a module that is not installed"
on master, puppet("module upgrade pmtacceptance-nginx"), :acceptable_exit_codes => [1] do
  assert_output <<-OUTPUT
    STDOUT> \e[mNotice: Preparing to upgrade 'pmtacceptance-nginx' ...\e[0m
    STDERR> \e[1;31mError: Could not upgrade module 'pmtacceptance-nginx'
    STDERR>   Module 'pmtacceptance-nginx' is not installed
    STDERR>     Use `puppet module install` to install this module\e[0m
  OUTPUT
end

step "Try to upgrade a local module"
on master, puppet("module upgrade nginx"), :acceptable_exit_codes => [1] do
  assert_output <<-OUTPUT
    STDOUT> \e[mNotice: Preparing to upgrade 'nginx' ...\e[0m
    STDOUT> \e[mNotice: Found 'nginx' (\e[0;36m???\e[m) in /etc/puppet/modules ...\e[0m
    STDERR> \e[1;31mError: Encountered the following problems:
    STDERR>   Not a valid full module name: nginx\e[0m
  OUTPUT
end

step "Try to upgrade a module that doesn't exist"
on master, puppet("module upgrade notpmtacceptance-unicorns"), :acceptable_exit_codes => [1] do
  assert_output <<-OUTPUT
    STDOUT> \e[mNotice: Preparing to upgrade 'notpmtacceptance-unicorns' ...\e[0m
    STDOUT> \e[mNotice: Found 'notpmtacceptance-unicorns' (\e[0;36mv0.0.3\e[m) in /etc/puppet/modules ...\e[0m
    STDOUT> \e[mNotice: Querying https://forge.puppetlabs.com ...\e[0m
    STDERR> \e[1;31mError: Could not execute operation for 'notpmtacceptance/unicorns'
    STDERR>   The server being queried was https://forge.puppetlabs.com
    STDERR>   The HTTP response we received was '410 Gone'
    STDERR>   The message we received said 'Module notpmtacceptance/unicorns not found'
    STDERR>     Check the author and module names are correct.\e[0m
  OUTPUT
end

step "Try to upgrade an installed module to a version that doesn't exist"
on master, puppet("module upgrade pmtacceptance-java --version 2.0.0"), :acceptable_exit_codes => [1] do
  assert_output <<-OUTPUT
    STDOUT> \e[mNotice: Preparing to upgrade 'pmtacceptance-java' ...\e[0m
    STDOUT> \e[mNotice: Found 'pmtacceptance-java' (\e[0;36mv1.6.0\e[m) in /etc/puppet/modules ...\e[0m
    STDOUT> \e[mNotice: Querying https://forge.puppetlabs.com ...\e[0m
    STDERR> \e[1;31mError: Could not execute operation for 'pmtacceptance/java'
    STDERR>   The server being queried was https://forge.puppetlabs.com
    STDERR>   The HTTP response we received was '410 Gone'
    STDERR>   The message we received said 'Found no releases satisfying: pmtacceptance/java (2.0.0)'
    STDERR>     Check the author and module names are correct.\e[0m
  OUTPUT
end
