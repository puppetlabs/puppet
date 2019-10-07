test_name "should allow param override"

tag 'audit:high',
    'audit:unit'   # This should be covered at the unit layer.

manifest = %q{
class parent {
  notify { 'msg':
    message => parent,
  }
}
class child inherits parent {
  Notify['msg'] {message => 'child'}
}
include parent
include child
}

apply_manifest_on(agents, manifest) do
    fail_test "parameter override didn't work" unless
        stdout.include? "defined 'message' as 'child'"
end

