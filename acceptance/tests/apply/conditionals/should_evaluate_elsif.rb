test_name "should evaluate the elsif block in a conditional"
manifest = %q{
if( 1 == 3) {
  notice('if')
} elsif(2 == 2) {
  notice('elsif')
} else {
  notice('else')
}
}

apply_manifest_on(agents, manifest) do
    fail_test "didn't evaluate elsif" unless stdout.include? 'elsif'
end

