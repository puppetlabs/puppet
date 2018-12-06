test_name "(#656) leading and trailing whitespace in cron entries should should be stripped"
confine :except, :platform => 'windows'
confine :except, :platform => /^eos-/ # See PUP-5500
tag 'audit:medium',
    'audit:refactor',  # Use block style `test_name`
    'audit:unit'

require 'puppet/acceptance/common_utils'
extend Puppet::Acceptance::CronUtils

teardown do
  step "Cron: cleanup"
  agents.each do |agent|
    clean agent
  end
end

agents.each do |host|
  step "create user account for testing cron entries"
  setup host

  step "apply the resource on the host using puppet resource"
  on(host, puppet_resource("cron", "crontest", "user=tstuser", "command='   date > /dev/null    '", "ensure=present")) do
    assert_match(/created/, stdout, "Did not create crontab for tstuser on #{host}")
  end

  step "verify the added crontab entry has stripped whitespace"
  run_cron_on(host, :list, 'tstuser') do
    assert_match(/\* \* \* \* \* date > .dev.null/, stdout, "Incorrect crontab for tstuser on #{host}")
  end

  step "apply the resource with trailing whitespace and check nothing happened"
  on(host, puppet_resource("cron", "crontest", "user=tstuser", "command='date > /dev/null    '", "ensure=present")) do
    assert_no_match(/ensure: created/, stdout, "Rewrote the line with trailing space in crontab for tstuser on #{host}")
  end

  step "apply the resource with leading whitespace and check nothing happened"
  on(host, puppet_resource("cron", "crontest", "user=tstuser", "command='     date > /dev/null'", "ensure=present")) do
    assert_no_match(/ensure: created/, stdout, "Rewrote the line with trailing space in crontab for tstuser on #{host}")
  end
end
