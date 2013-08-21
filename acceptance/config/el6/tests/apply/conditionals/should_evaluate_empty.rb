test_name "ensure that undefined variables evaluate as false"
manifest = %q{
if $undef_var {
} else {
  notice('undef')
}
}

apply_manifest_on(agents, manifest) do
    fail_test "did not evaluate as expected" unless stdout.include? 'undef'
end

