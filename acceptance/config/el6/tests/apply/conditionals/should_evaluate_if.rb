test_name = "should evaluate an if block correctly"
manifest = %q{
if( 1 == 1) {
  notice('if')
} elsif(2 == 2) {
  notice('elsif')
} else {
  notice('else')
}
}

apply_manifest_on(agents, manifest) do
    fail_test "didn't evaluate correctly" unless stdout.include? 'if'
end

