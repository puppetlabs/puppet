test_name "hash reassignment should fail"

tag 'audit:high',
    'audit:unit',  # This should be covered at the unit layer.
    'audit:delete'

manifest = %q{
$my_hash = {'one' => '1', 'two' => '2' }
$my_hash['one']='1.5'
}

agents.each do |host|
  apply_manifest_on(host, manifest, :acceptable_exit_codes => [1]) do
    expected_error_message = "Illegal attempt to assign via [index/key]. Not an assignable reference"
    fail_test("didn't find the failure") unless stderr.include?(expected_error_message) || agent['locale'] == 'ja'
  end
end
