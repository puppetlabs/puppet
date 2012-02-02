test_name "puppet module list test output and dependency error checking"

step "Run puppet module list"
expected_stdout = <<-HEREDOC
/opt/puppet-git-repos/puppet/acceptance/tests/modules/fake_modulepath
  mysql (0.0.0)
  apache (0.0.3)
  bacula (0.0.2)
  sqlite (0.0.1.1)
  HEREDOC

expected_stderr = <<-HEREDOC
Missing dependency `create_resources`:
  `mysql` (0.0.0) requires `bodepd/create_resources` (>= 0.0.1)
Missing dependency `stdlib`:
  `bacula` (0.0.2) requires `puppetlabs/stdlib` (>= 2.2.0)
Version dependency mismatch `mysql` (0.0.0):
  `bacula` (0.0.2) requires `puppetlabs/mysql` (>= 0.0.1)
Non semantic version dependency `sqlite` (0.0.1.1):
  `bacula` (0.0.2) requires `puppetlabs/sqlite` (>= 0.0.1)
  HEREDOC

on master, "puppet module list --modulepath /opt/puppet-git-repos/puppet/acceptance/tests/modules/fake_modulepath" do
  assert_match(expected_stdout, stdout, "puppet module list did not output expected stdout")
  assert_match(expected_stderr, stderr, "puppet module list did not output expected stderr")
end
