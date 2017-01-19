test_name 'utf-8 characters in resource title and param values'

confine :except, :platform => [ 'windows', 'ubuntu-16']   # PUP-6983

utf8chars = "€‰ㄘ万竹ÜÖ"

agents.each do |agent|
  agent_file = agent.tmpfile("file" + utf8chars) 
  # remove this file, so puppet can create it and not merely correct
  # its drift.
  result = on(agent, "rm -rf #{agent_file}")

  manifest =<<PP

file { "#{agent_file}" :
  ensure => file,
  mode => "0644",
  content => "This is the file content. file #{utf8chars} 
",
}

PP

  step "Apply manifest"
  result = apply_manifest_on(
    agent,
    manifest,
    {:acceptable_exit_codes => [0, 2], :catch_failures => true, }
  )
  result = on(agent, "cat #{agent_file}")
  assert_equal(result.exit_code, 0)
  assert_match(/#{utf8chars}/, result.stdout, "result stdout did not contain")

  step "Drift correction"
  result = on(agent, "> #{agent_file}")
  result = on(agent, "cat #{agent_file}")
  assert_equal(result.stdout, "", "expected empty file")
  result = apply_manifest_on(
    agent,
    manifest,
    {:acceptable_exit_codes => [0, 2], :catch_failures => true, }
  )
  result = on(agent, "cat #{agent_file}")
  assert_equal(result.exit_code, 0)
  assert_match(/#{utf8chars}/, result.stdout, "result stdout did not contain")
end


