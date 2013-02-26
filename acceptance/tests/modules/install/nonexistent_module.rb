test_name "puppet module install (nonexistent module)"

step 'Setup'

stub_forge_on(master)

# Ensure module path dirs are purged before and after the tests
apply_manifest_on master, "file { ['/etc/puppet/modules', '/usr/share/puppet/modules']: ensure => directory, recurse => true, purge => true, force => true }"
teardown do
  on master, "rm -rf /etc/puppet/modules"
  on master, "rm -rf /usr/share/puppet/modules"
end

step "Try to install a non-existent module"
on master, puppet("module install pmtacceptance-nonexistent"), :acceptable_exit_codes => [1] do
  assert_output <<-OUTPUT
    STDOUT> \e[mNotice: Preparing to install into /etc/puppet/modules ...\e[0m
    STDOUT> \e[mNotice: Downloading from https://forge.puppetlabs.com ...\e[0m
    STDERR> \e[1;31mError: Could not execute operation for 'pmtacceptance/nonexistent'
    STDERR>   The server being queried was https://forge.puppetlabs.com
    STDERR>   The HTTP response we received was '410 Gone'
    STDERR>   The message we received said 'Module pmtacceptance/nonexistent not found'
    STDERR>     Check the author and module names are correct.\e[0m
  OUTPUT
end

step "Try to install a non-existent module (JSON rendering)"
on master, puppet("module --render-as json install pmtacceptance-nonexistent") do
  require 'json'
  str  = stdout.lines.to_a.last
  json = JSON.parse(str)

  oneline_expectation   = %[Could not execute operation for 'pmtacceptance/nonexistent'. Detail: Module pmtacceptance/nonexistent not found / 410 Gone.]
  multiline_expectation = <<-OUTPUT.chomp
Could not execute operation for 'pmtacceptance/nonexistent'
  The server being queried was https://forge.puppetlabs.com
  The HTTP response we received was '410 Gone'
  The message we received said 'Module pmtacceptance/nonexistent not found'
    Check the author and module names are correct.
OUTPUT


  assert_equal nil,                         json['module_version']
  assert_equal 'pmtacceptance-nonexistent', json['module_name']
  assert_equal 'failure',                   json['result']
  assert_equal '/etc/puppet/modules',       json['install_dir']
  assert_equal multiline_expectation,       json['error']['multiline']
  assert_equal oneline_expectation,         json['error']['oneline']
end

