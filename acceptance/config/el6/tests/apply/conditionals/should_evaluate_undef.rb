test_name "empty string should evaluate as false"
manifest = %q{
if '' {
} else {
  notice('empty')
}
}

apply_manifest_on(agents, manifest) do
    fail_test "didn't evaluate as false" unless stdout.include? 'empty'
end
