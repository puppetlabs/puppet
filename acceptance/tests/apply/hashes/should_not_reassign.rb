test_name "hash reassignment should fail"
manifest = %q{
$my_hash = {'one' => '1', 'two' => '2' }
$my_hash['one']='1.5'
}

apply_manifest_on(agents, manifest, :acceptable_exit_codes => [1]) do
    fail_test "didn't find the failure" unless
        stderr.include? "Assigning to the hash 'my_hash' with an existing key 'one'"
end
