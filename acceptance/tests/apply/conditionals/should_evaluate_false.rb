test_name "test that false evaluates to false"
manifest = %q{
if false {
} else {
  notice('false')
}
}

apply_manifest_on(agents, manifest) do
    fail_test "didn't evaluate false correcly" unless stdout.include? 'false'
end

