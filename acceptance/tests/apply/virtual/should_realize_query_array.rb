test_name "should realize query array"
out  = "/tmp/hosts-#{Time.new.to_i}"
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
on agents, "rm -f #{out}"

step "run the manifest"
apply_manifest_on agents, manifest

step "verify the file output"
on(agents, "cat #{out}") do
    fail_test "host not found in output" unless stdout.include? name
end
