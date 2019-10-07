test_name "resources declared in a class can be applied with include"

tag 'audit:high',
    'audit:unit'   # This should be covered at the unit layer.

manifest = %q{
class x {
  notify{'a':}
}
include x
}
apply_manifest_on(agents, manifest) do
    fail_test "the resource did not apply" unless
        stdout.include? "defined 'message' as 'a'"
end
