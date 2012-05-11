test_name "Bug #4287: undefined method 'evaluate_match' when function call used in an 'if' statement"

manifest = %q{
  $foo='abc'
  if $foo != regsubst($foo,'abc','def') {
    notify { 'No issue here...': }
  }
}

agents.each do |host|
  apply_manifest_on(host, manifest) do
    assert_match(/No issue here.../, stdout, "didn't get the expected notice on #{host}")
  end
end
