test_name "`puppet resource service` should list running services without changing the system"

confine :except, :platform => 'windows'

hosts.each do |host|
  step "make sure ssh reports running"

  # We want to validate later that ssh is "still" running, which means it has
  # to be running to start with
  on host, 'puppet resource service ssh'
  assert_match /service { 'ssh[^']*':\n\s*ensure\s*=>\s*'(?:true|running)'/, stdout, "ssh is not running"

  step "list running services"

  on host, 'puppet resource service'
  expected_output = stdout

  step "make sure nothing on the system was changed"

  on host, 'puppet resource service'
  assert_equal expected_output, stdout, "`puppet resource service` changed the state of the system"

  step "make sure ssh is still running"

  # We know ssh must be running, since we're using it to test. It should still
  # be running after `puppet resource service`.
  on host, 'puppet resource service ssh'
  assert_match /service { 'ssh[^']*':\n\s*ensure\s*=>\s*'(?:true|running)'/, stdout, "`puppet resource service` changed the state of the system"
end
