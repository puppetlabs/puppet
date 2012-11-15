test_name "should not rewrite if the job has trailing whitespace"
confine :except, :platform => 'windows'

require 'puppet/acceptance/common_utils'
extend Puppet::Acceptance::CronUtils

agents.each do |host|
  step "ensure the user exist via puppet"
  setup host

  step "apply the resource on the host using puppet resource"
  on(host, puppet_resource("cron", "crontest", "user=tstuser", "command='date > /dev/null    '", "ensure=present")) do
    assert_match(/created/, stdout, "Did not create crontab for tstuser on #{host}")
  end

  step "verify that crontab -l contains what you expected"
  run_cron_on(host, :list, 'tstuser') do
    assert_match(/\* \* \* \* \* date > .dev.null    /, stdout, "Incorrect crontab for tstuser on #{host}")
  end

  step "apply the resource again on the host using puppet resource and check nothing happened"
  on(host, puppet_resource("cron", "crontest", "user=tstuser", "command='date > /dev/null'", "ensure=present")) do
    assert_no_match(/ensure: created/, stdout, "Rewrote the line with trailing space in crontab for tstuser on #{host}")
  end
end
