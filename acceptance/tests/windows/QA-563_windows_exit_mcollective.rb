test_name 'MCollective service exits on windows agent'

tag 'risk:medium'

confine :to, :platform => 'windows'
confine :to, {}, hosts.select { |host| (host[:roles].include?('aio')) }

step 'Setup - ensure MCollective service is running on Windows agent'
on agent, puppet('resource service mcollective ensure=running')

step 'Shutdown MCollective service on Windows agent'

#Shutdown MCollective Service on Windows agent and make sure it successfully exits
agents.each do |agent|
  on agent, 'net stop mcollective' do |result|
    assert_match(/The Marionette Collective Server service was stopped successfully/, result.stdout, "Failed to stop MCollective service")
  end
end

sleep 5

step 'Start MCollective service on Windows agent'

#Bring the MCllective backup
agents.each do |agent|
  on agent, 'net start mcollective' do |result|
    assert_match(/The Marionette Collective Server service was started successfully/, result.stdout, "Failed to start MCollective service")
  end
end


