test_name "puppet module list test output and dependency error checking"

step "Run puppet module list"
expected_stdout = <<-HEREDOC.strip
/opt/puppet-git-repos/puppet/acceptance/tests/modules/fake_modulepath
├── puppetlabs-apache (v0.0.3)
├── puppetlabs-bacula (v0.0.2)
├── puppetlabs-mysql (v0.0.0) invalid
└── puppetlabs-sqlite (v0.0.1.1)
  HEREDOC

expected_stderr = <<-HEREDOC.strip
\e[1;31mWarning: Non semantic version dependency 'puppetlabs-sqlite' (v0.0.1.1):
  'puppetlabs-bacula' (v0.0.2) requires 'puppetlabs-sqlite' (>= 0.0.1)\e[0m
\e[1;31mWarning: Module 'puppetlabs-mysql' (v0.0.0) fails to meet some dependencies:
  'puppetlabs-bacula' (v0.0.2) requires 'puppetlabs-mysql' (>= 0.0.1)\e[0m
\e[1;31mWarning: Missing dependency 'bodepd-create_resources':
  'puppetlabs-mysql' (v0.0.0) requires 'bodepd-create_resources' (>= 0.0.1)\e[0m
\e[1;31mWarning: Missing dependency 'puppetlabs-stdlib':
  'puppetlabs-bacula' (v0.0.2) requires 'puppetlabs-stdlib' (>= 2.2.0)\e[0m
  HEREDOC

on master, "puppet module list --modulepath /opt/puppet-git-repos/puppet/acceptance/tests/modules/fake_modulepath" do
  assert_equal(expected_stdout, stdout.strip, "puppet module list did not output expected stdout")
  assert_equal(expected_stderr, stderr.strip, "puppet module list did not output expected stderr")
end
