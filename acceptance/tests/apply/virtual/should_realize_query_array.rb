test_name "should realize query array"

agents.each do |agent|
  out  = agent.tmpfile('should_realize_query_array')
  name = "test-#{Time.new.to_i}-host"

manifest = %Q{
  @host { '#{name}':
    ip           => '127.0.0.2',
    target       => '#{out}',
    host_aliases => ['one', 'two', 'three'],
    ensure       => present,
  }
  Host<| host_aliases == 'two' |>
}

  step "clean up target system for test"
  on agent, "rm -f #{out}"

  step "run the manifest"
  apply_manifest_on agent, manifest

  step "verify the file output"
  on(agent, "cat #{out}") do
    fail_test "host not found in output" unless stdout.include? name
  end
end
