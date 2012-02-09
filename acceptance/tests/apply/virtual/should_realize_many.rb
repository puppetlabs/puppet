test_name "test that realize function takes a list"

agents.each do |agent|
  out  = agent.tmpfile('should_realize_many')
  name = "test-#{Time.new.to_i}-host"

manifest = %Q{
  @host{'#{name}1': ip=>'127.0.0.2', target=>'#{out}', ensure=>present}
  @host{'#{name}2': ip=>'127.0.0.2', target=>'#{out}', ensure=>present}
  realize(Host['#{name}1'], Host['#{name}2'])
}

  step "clean up target system for test"
  on agent, "rm -f #{out}"

  step "run the manifest"
  apply_manifest_on agent, manifest

  step "verify the file output"
  on(agent, "cat #{out}") do
    fail_test "first host not found in output" unless stdout.include? "#{name}1"
    fail_test "second host not found in output" unless stdout.include? "#{name}2"
  end
end
