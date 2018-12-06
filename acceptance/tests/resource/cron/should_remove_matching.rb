test_name "puppet should remove a crontab entry based on command matching"
confine :except, :platform => 'windows'
confine :except, :platform => /^eos-/ # See PUP-5500
tag 'audit:medium',
    'audit:refactor',  # Use block style `test_name`
    'audit:acceptance' # Could be done at the integration (or unit) layer though
                       # actual changing of resources could irreparably damage a
                       # host running this, or require special permissions.

require 'puppet/acceptance/common_utils'
extend Puppet::Acceptance::CronUtils

teardown do
  step "Cron: cleanup"
  agents.each do |agent|
    clean agent
  end
end

agents.each do |host|
  step "ensure the user exist via puppet"
  setup host

  step "create the existing job by hand..."
  run_cron_on(host,:add,'tstuser',"* * * * * /bin/true")

  step "Remove cron resource"
  on(host, puppet_resource("cron", "bogus", "user=tstuser",
                           "command=/bin/true", "ensure=absent")) do
    assert_match(/bogus\D+ensure: removed/, stdout, "Removing cron entry failed for tstuser on #{host}")
  end

  step "verify that crontab -l contains what you expected"
  run_cron_on(host,:list,'tstuser') do
    count = stdout.scan("/bin/true").length
    fail_test "found /bin/true the wrong number of times (#{count})" unless count == 0
  end

end
