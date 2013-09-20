test_name "should realize"

agents.each do |agent|
  out  = agent.tmpfile('should_realize')
  name = "test-#{Time.new.to_i}-host"

manifest = %Q{
  @host{'#{name}': ip=>'127.0.0.2', target=>'#{out}', ensure=>present}
  realize(Host['#{name}'])
}

  step "clean the system ready for testing"
  on agent, "rm -f #{out}"

  step "realize the resource on the host"
  apply_manifest_on agent, manifest

  step "verify the content of the file"
  on(agent, "cat #{out}") do
    fail_test "missing host definition" unless stdout.include? name
  end

  step "final cleanup of the system"
  on agent, "rm -f #{out}"
end
