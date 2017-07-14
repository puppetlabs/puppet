test_name "Cron: should allow changing parameters after creation"
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


agents.each do |agent|
  step "ensure the user exist via puppet"
  setup agent

  step "Cron: basic - verify that it can be created"
  apply_manifest_on(agent, 'cron { "myjob": command => "/bin/false", user    => "tstuser", hour    => "*", minute  => [1], ensure  => present,}') do
    assert_match( /ensure: created/, result.stdout, "err: #{agent}")
  end
  run_cron_on(agent,:list,'tstuser') do
    assert_match(/.bin.false/, result.stdout, "err: #{agent}")
  end

  step "Cron: allow changing command"
  apply_manifest_on(agent, 'cron { "myjob": command => "/bin/true", user    => "tstuser", hour    => "*", minute  => [1], ensure  => present,}') do
    assert_match(/command changed '.bin.false'.* to '.bin.true'/, result.stdout, "err: #{agent}")
  end
  run_cron_on(agent,:list,'tstuser') do
    assert_match(/1 . . . . .bin.true/, result.stdout, "err: #{agent}")
  end

  step "Cron: allow changing time"
  apply_manifest_on(agent, 'cron { "myjob": command => "/bin/true", user    => "tstuser", hour    => "1", minute  => [1], ensure  => present,}') do
    assert_match(/hour: defined 'hour' as \['1'\]/, result.stdout, "err: #{agent}")
  end
  run_cron_on(agent,:list,'tstuser') do
    assert_match(/1 1 . . . .bin.true/, result.stdout, "err: #{agent}")
  end

  step "Cron: allow changing time(array)"
  apply_manifest_on(agent, 'cron { "myjob": command => "/bin/true", user    => "tstuser", hour    => ["1","2"], minute  => [1], ensure  => present,}') do
    assert_match(/hour: hour changed \['1'\].* to \['1', '2'\]/, result.stdout, "err: #{agent}")
  end
  run_cron_on(agent,:list,'tstuser') do
    assert_match(/1 1,2 . . . .bin.true/, result.stdout, "err: #{agent}")
  end

  step "Cron: allow changing time(array modification)"
  apply_manifest_on(agent, 'cron { "myjob": command => "/bin/true", user    => "tstuser", hour    => ["3","2"], minute  => [1], ensure  => present,}') do
    assert_match(/hour: hour changed \['1', '2'\].* to \['3', '2'\]/, result.stdout, "err: #{agent}")
  end
  run_cron_on(agent,:list,'tstuser') do
    assert_match(/1 3,2 . . . .bin.true/, result.stdout, "err: #{agent}")
  end
  step "Cron: allow changing time(array modification to *)"
  apply_manifest_on(agent, 'cron { "myjob": command => "/bin/true", user    => "tstuser", hour    => "*", minute  => "*", ensure  => present,}') do
    assert_match(/minute: undefined 'minute' from \['1'\]/,result.stdout, "err: #{agent}")
    assert_match(/hour: undefined 'hour' from \['3', '2'\]/,result.stdout, "err: #{agent}")
  end
  run_cron_on(agent,:list,'tstuser') do
    assert_match(/\* \* . . . .bin.true/, result.stdout, "err: #{agent}")
  end

end
