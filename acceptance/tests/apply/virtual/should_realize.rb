test_name "should realize"
out  = "/tmp/hosts-#{Time.new.to_i}"
name = "test-#{Time.new.to_i}-host"

manifest = %Q{
  @host{'#{name}': ip=>'127.0.0.2', target=>'#{out}', ensure=>present}
  realize(Host['#{name}'])
}

step "clean the system ready for testing"
on agents, "rm -f #{out}"

step "realize the resource on the hosts"
apply_manifest_on agents, manifest

step "verify the content of the file"
on(agents, "cat #{out}") do
    fail_test "missing host definition" unless stdout.include? name
end

step "final cleanup of the system"
on agents, "rm -f #{out}"
