test_name "Reports are finalized on resource cycles"
# PUP-4548: Skip Windows until PUP-4547 can be resolved.
confine :except, :platform => 'windows'
skip_test "requires AIO install to require 'puppet'" if @options[:type] != 'aio'
tag 'audit:medium',
    'audit:integration'

require 'puppet/acceptance/common_utils'
extend Puppet::Acceptance::CommandUtils

check_script = <<CHECK
require 'yaml'
require 'puppet'

exit YAML.load_file(ARGV[0]).metrics.empty? ? 1 : 0
CHECK

cyclic_manifest = <<MANIFEST
notify { 'foo':
  require => Notify['bar']
}

notify { 'bar':
  require => Notify['foo']
}
MANIFEST

agents.each do |agent|
  tmpdir = agent.tmpdir('report_finalized')
  check = "#{tmpdir}/check_report.rb"
  manifest = "#{tmpdir}/manifest.pp"
  report = agent.puppet['lastrunreport']

  create_remote_file(agent, check, check_script)

  # We can't use apply_manifest_on here because we can't tell it not
  # to fail the test when it encounters a cyclic manifest.
  create_remote_file(agent, manifest, cyclic_manifest)
  on(agent, puppet("apply", manifest), :acceptable_exit_codes => [1])
  result = on(agent, "#{ruby_command(agent)} #{check} #{report}", :acceptable_exit_codes => [0,1])
  fail_test("Report was not finalized") if result.exit_code == 1
end
