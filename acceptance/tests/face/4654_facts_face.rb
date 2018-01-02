test_name "Puppet facts face should resolve custom and external facts"

tag 'audit:medium',
    'audit:integration'   # The facter acceptance tests should be acceptance.
                          # However, the puppet face merely needs to interact with libfacter.
                          # So, this should be an integration test.
#
# This test is intended to ensure that custom and external facts present
# on the agent are resolved and displayed by the puppet facts face.
#
custom_fact = <<CFACT
Facter.add('custom_fact') do
  setcode do
    'foo'
  end
end
CFACT

unix_external_fact = <<EFACT
#!/bin/sh
echo 'external_fact=bar'
EFACT

win_external_fact = <<EFACT
@echo off
echo external_fact=bar
EFACT

agents.each do |agent|
  if agent['platform'] =~ /windows/
    external_fact = win_external_fact
    ext = '.bat'
  else
    external_fact = unix_external_fact
    ext = '.sh'
  end

  step "Create custom and external facts in their default directories on the agent"

  teardown do
    on agent, "rm -rf #{agent.puppet['plugindest']}/facter"
    on agent, "rm -rf #{agent.puppet['pluginfactdest']}/external#{ext}"
  end

  on agent, puppet('apply'), :stdin => <<MANIFEST
  file { "#{agent.puppet['plugindest']}/facter":
    ensure => directory,
  }

  file { "#{agent.puppet['plugindest']}/facter/custom.rb":
    ensure  => file,
    content => "#{custom_fact}",
  }

  file { "#{agent.puppet['pluginfactdest']}/external#{ext}":
    ensure  => file,
    mode    => "0755",
    content => "#{external_fact}",
  }
MANIFEST

  step "Agent #{agent}: custom_fact and external_fact should be present in the output of `puppet facts`"
  on agent, puppet('facts') do
    assert_match(/"custom_fact": "foo"/, stdout, "custom_fact did not match expected output")
    assert_match(/"external_fact": "bar"/, stdout, "external_fact did not match expected output")
  end
end
