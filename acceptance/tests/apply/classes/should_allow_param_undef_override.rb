test_name "should allow overriding a parameter to undef in inheritence"

tag 'audit:high',
    'audit:unit'   # This should be covered at the unit layer.

agents.each do |agent|
  dir = agent.tmpdir('class_undef_override')
  out = File.join(dir, 'class_undef_override_out')
  source = File.join(dir, 'class_undef_override_test')

manifest = %Q{
  class parent {
    file { 'test':
      path   => '#{out}',
      source => '#{source}',
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
  on(agent, "echo 'hello world!' > #{out}")
  step "apply the manifest"
  apply_manifest_on(agent, manifest)
  step "verify the file content"
  on(agent, "cat #{out}") do
    fail_test "the file was not touched" if stdout.include? "hello world!"
    fail_test "the file was not updated" unless stdout.include? "hello new world"
  end

  on(agent, "rm -rf #{dir}")
end
