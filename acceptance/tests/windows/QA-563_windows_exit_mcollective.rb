test_name 'MCollective service exits on windows agent'

tag 'risk:medium',
    'audit:medium',
    'audit:refactor',   # Use block style `test_name`
    'audit:acceptance'

confine :to, :platform => 'windows'
confine :to, {}, hosts.select { |host| (host[:roles].include?('aio')) }

step 'Setup - create a config file'
# this step should be deleted after MCO-727 is resolved
config_content =<<EOS
  main_collective = mcollective
  collectives = mcollective

  libdir = C:/ProgramData/PuppetLabs/mcollective/plugins

  logfile = C:/ProgramData/PuppetLabs/mcollective/var/log/mcollective.log
  loglevel = debug
  daemonize = 1

  # Plugins
  securityprovider = psk
  plugin.psk = unset

  connector = activemq
  plugin.activemq.pool.size = 1
  plugin.activemq.pool.1.host = stomp1
  plugin.activemq.pool.1.port = 6163
  plugin.activemq.pool.1.user = mcollective
  plugin.activemq.pool.1.password = marionette

  # Facts
  factsource = yaml
  plugin.yaml = C:/ProgramData/PuppetLabs/mcollective/facts.yaml
EOS

manifest = <<MANIFEST
  file { 'C:/ProgramData/PuppetLabs/mcollective/etc/server.cfg':
    ensure  => present,
    content => '#{config_content}',
  }
MANIFEST

agents.each do |agent|
  apply_manifest_on(agent, manifest, :catch_failures => true)
end

step 'Setup - ensure MCollective service is running on Windows agent'
agents.each do |agent|
  on agent, puppet('resource service mcollective ensure=running')
end

step 'Shutdown MCollective service on Windows agent'
#Shutdown MCollective Service on Windows agent and make sure it successfully exits
agents.each do |agent|
  on agent, 'net stop mcollective'
end

sleep 5

step 'Start MCollective service on Windows agent'
#Bring the MCllective backup
agents.each do |agent|
  on agent, 'net start mcollective'
end
