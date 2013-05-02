test_name "`puppet resource service` should list running services without changing the system"

confine :except, :platform => 'windows'
confine :except, :platform => 'solaris'


hosts.each do |host|
  step "list running services and make sure ssh reports running"

  on host, 'puppet resource service'
  assert_match /service { 'ssh[^']*':\n\s*ensure\s*=>\s*'(?:true|running)'/, stdout, "ssh is not running"
  expected_output = stdout

  step "make sure nothing on the system was changed and ssh is still running"

  on host, 'puppet resource service'

  # It's possible that `puppet resource service` changed the system before
  # printing output the *first* time, so in addition to comparing the output,
  # we also want to check that a known service is in a good state. We use ssh
  # because our tests run over ssh, so it must be present.
  assert_match /service { 'ssh[^']*':\n\s*ensure\s*=>\s*'(?:true|running)'/, stdout, "ssh is no longer running"
  assert_equal expected_output, stdout, "`puppet resource service` changed the state of the system"
end
