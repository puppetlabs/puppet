test_name "`puppet resource service` should list running services without calling dangerous init scripts"

confine :except, :platform => 'windows'
confine :except, :platform => 'solaris'

# For each script in /etc/init.d, the init service provider will call
# the script with the `status` argument, except for blacklisted
# scripts that are known to be dangerous, e.g. /etc/init.d/reboot.sh
# The first execution of `puppet resource service` will enumerate
# all services, and we want to check that puppet enumerates at
# least one service. We use ssh because our tests run over ssh, so it
# must be present.

agents.each do |agent|
  step "list running services and make sure ssh reports running"
  on(agent, puppet('resource service'))
  assert_match /service { 'ssh[^']*':\n\s*ensure\s*=>\s*'(?:true|running)'/, stdout, "ssh is not running"

  step "list running services again and make sure ssh is still running"
  on(agent, puppet('resource service'))
  assert_match /service { 'ssh[^']*':\n\s*ensure\s*=>\s*'(?:true|running)'/, stdout, "ssh is no longer running"
end
