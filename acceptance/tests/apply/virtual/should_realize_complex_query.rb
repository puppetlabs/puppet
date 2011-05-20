test_name "should realize with complex query"
out  = "/tmp/hosts-#{Time.new.to_i}"
name = "test-#{Time.new.to_i}-host"

manifest = %Q{
  @host { '#{name}1':
    ip           => '127.0.0.2',
    target       => '#{out}',
    host_aliases => ['one', 'two', 'three'],
    ensure       => present,
  }
  @host { '#{name}2':
    ip           => '127.0.0.3',
    target       => '#{out}',
    host_aliases => 'two',
    ensure       => present,
  }
  Host<| host_aliases == 'two' and ip == '127.0.0.3' |>
}

step "clean up target system for test"
on agents, "rm -f #{out}"

step "run the manifest"
apply_manifest_on agents, manifest

step "verify the file output"
on(agents, "cat #{out}") do
    fail_test "second host not found in output" unless
        stdout.include? "#{name}2"
    fail_test "first host was found in output" if
        stdout.include? "#{name}1"
end

step "clean up system after testing"
on agents, "rm -f #{out}"
