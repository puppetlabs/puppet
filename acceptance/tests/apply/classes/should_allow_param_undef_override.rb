test_name "should allow overriding a parameter to undef in inheritence"

out = "/tmp/class_undef_override_out-#{$$}"
manifest = %Q{
  class parent {
    file { 'test':
      path   => '#{out}',
      source => '/tmp/class_undef_override_test-#{$$}',
    }
  }
  class child inherits parent {
    File['test'] {
      source  => undef,
      content => 'hello new world!',
    }
  }
  include parent
  include child
}

step "prepare the target file on all systems"
on(agents, "echo 'hello world!' > #{out}")
step "apply the manifest"
apply_manifest_on(agents, manifest)
step "verify the file content"
on(agents, "cat #{out}") do
    fail_test "the file was not touched" if stdout.include? "hello world!"
    fail_test "the file was not updated" unless stdout.include? "hello new world"
end
