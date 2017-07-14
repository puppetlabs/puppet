test_name "should create cron"
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

  step "apply the resource on the host using puppet resource"
  on(host, puppet_resource("cron", "crontest", "user=tstuser",
                           "command=/bin/true", "ensure=present")) do
    assert_match(/created/, stdout, "Did not create crontab for tstuser on #{host}")
  end

  step "verify that crontab -l contains what you expected"
  run_cron_on(host, :list, 'tstuser') do
    assert_match(/\* \* \* \* \* \/bin\/true/, stdout, "Incorrect crontab for tstuser on #{host}")
  end

end
