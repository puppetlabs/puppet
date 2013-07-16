test_name "test that the string 'false' evaluates to true"
manifest = %q{
if 'false' {
  notice('true')
} else {
  notice('false')
}
}

apply_manifest_on(agents, manifest) do
    fail_test "string 'false' didn't evaluate as true" unless
        stdout.include? 'true'
end
