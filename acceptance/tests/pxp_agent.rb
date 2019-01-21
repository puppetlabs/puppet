test_name 'pxp-agent'

teardown do
  agents.each do |agent|
    on(agent, 'launchctl unload /Library/LaunchDaemons/com.puppetlabs.pxp-agent.plist')
  end
end

step 'is disabled by default on osx'
agents.each do |agent|
  on(agent, 'launchctl load /Library/LaunchDaemons/com.puppetlabs.pxp-agent.plist')
  on(agent, puppet('resource service pxp-agent')) do
    if agent.platform =~ /osx/
      assert_match(/ensure => .stopped.,/, result.stdout,
                   "pxp-agent not in expected stopped state")
    else
      assert_match(/ensure => .running.,/, result.stdout,
                   "pxp-agent not in expected running state")
    end
  end
end
