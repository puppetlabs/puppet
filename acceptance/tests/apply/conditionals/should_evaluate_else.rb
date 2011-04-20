test_name "else clause will be reached if no expressions match"
manifest = %q{
if( 1 == 2) {
  notice('if')
} elsif(2 == 3) {
  notice('elsif')
} else {
  notice('else')
}
}

apply_manifest_on(agents, manifest) do
    fail_test "the else clause did not evaluate" unless stdout.include? 'else'
end

