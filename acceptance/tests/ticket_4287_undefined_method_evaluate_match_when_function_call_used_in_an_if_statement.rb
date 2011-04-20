test_name "Bug #4287: undefined method 'evaluate_match' when function call used in an 'if' statement"

manifest = %q{
  $foo='abc'
  if $foo != regsubst($foo,'abc','def') {
    notify { 'No issue here...': }
  }
}

apply_manifest_on(agents, manifest) do
    fail_test "didn't get the expected notice" unless
        stdout.include? 'notice: No issue here...'
end
