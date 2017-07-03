test_name "`puppet resource service` should list running services without calling dangerous init scripts"

tag 'audit:medium',
    'audit:refactor',   # Use block style `test_name`
    'audit:integration' # Doesn't change the system it runs on

confine :except, :platform => 'windows'
confine :except, :platform => 'solaris'
confine :except, :platform => /^cisco_/ # See PUP-5827

# For each script in /etc/init.d, the init service provider will call
# the script with the `status` argument, except for blacklisted
# scripts that are known to be dangerous, e.g. /etc/init.d/reboot.sh
# The first execution of `puppet resource service` will enumerate
# all services, and we want to check that puppet enumerates at
# least one service. We use ssh because our tests run over ssh, so it
# must be present.

agents.each do |agent|
  service_name = case agent['platform']
                 when /osx/
                   "com.openssh.sshd"
                 else
                   "ssh[^']*"
                 end

  step "list running services and make sure ssh reports running"
  on(agent, puppet('resource service'))
  assert_match /service { '#{service_name}':\n\s*ensure\s*=>\s*'(?:true|running)'/, stdout, "ssh is not running"

  step "list running services again and make sure ssh is still running"
  on(agent, puppet('resource service'))
  assert_match /service { '#{service_name}':\n\s*ensure\s*=>\s*'(?:true|running)'/, stdout, "ssh is no longer running"
end
