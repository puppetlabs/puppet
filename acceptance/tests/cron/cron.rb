test_name "Cron: test cases for cron"
confine :to, :platform => 'solaris'

require 'puppet/acceptance/solaris_util'
extend Puppet::Acceptance::CronUtils

teardown do
  step "Cron: cleanup"
  agents.each do |agent|
    clean agent
  end
end


agents.each do |agent|
  clean agent
  setup agent

  step "Cron: basic - verify that it can be created"
  apply_manifest_on(agent, 'cron { "myjob": command => "/opt/bin/test.pl", user    => "root", hour    => "*", minute  => [1], ensure  => present,}') do
    assert_match( /ensure: created/, result.stdout, "err: #{agent}")
  end
  on agent, "crontab -l" do
    assert_match(/myjob/, result.stdout, "err: #{agent}")
  end

  step "Cron: basic - should not create again"
  apply_manifest_on(agent, 'cron { "myjob": command => "/opt/bin/test.pl", user    => "root", hour    => "*", minute  => [1], ensure  => present,}') do
    assert_no_match( /ensure: created/, result.stdout, "err: #{agent}")
  end

  step "Cron: allow changing command"
  apply_manifest_on(agent, 'cron { "myjob": command => "/opt/bin/new.pl", user    => "root", hour    => "*", minute  => [1], ensure  => present,}') do
    assert_match(/command changed '.opt.bin.test.pl' to '.opt.bin.new.pl'/, result.stdout, "err: #{agent}")
  end
  step "Cron: allow changing time"
  apply_manifest_on(agent, 'cron { "myjob": command => "/opt/bin/new.pl", user    => "root", hour    => "1", minute  => [1], ensure  => present,}') do
    assert_match(/hour: defined 'hour' as '1'/, result.stdout, "err: #{agent}")
  end
  step "Cron: allow changing time(array)"
  apply_manifest_on(agent, 'cron { "myjob": command => "/opt/bin/new.pl", user    => "root", hour    => ["1","2"], minute  => [1], ensure  => present,}') do
    assert_match(/hour: hour changed '1' to '1,2'/, result.stdout, "err: #{agent}")
  end
  step "Cron: allow changing time(array modification)"
  apply_manifest_on(agent, 'cron { "myjob": command => "/opt/bin/new.pl", user    => "root", hour    => ["3","2"], minute  => [1], ensure  => present,}') do
    assert_match(/hour: hour changed '1,2' to '3,2'/, result.stdout, "err: #{agent}")
  end

  step "Cron: basic - remove"
  apply_manifest_on(agent, "cron { 'myjob':  ensure=>absent, }") do
    assert_match(/ensure: removed/, result.stdout, "err: #{agent}")
  end

  step "Cron: ensure removed"
  on agent, "crontab -l" do
    assert_no_match(/myjob/, result.stdout, "err: #{agent}")
  end
end
