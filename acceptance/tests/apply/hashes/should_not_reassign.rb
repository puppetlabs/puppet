test_name "hash reassignment should fail"
manifest = %q{
$my_hash = {'one' => '1', 'two' => '2' }
$my_hash['one']='1.5'
}

agents.each do |host|
  parser = on(host, puppet('agent --configprint parser')).stdout.chomp
  apply_manifest_on(host, manifest, :acceptable_exit_codes => [1]) do
    expected_error_message =
    case parser
    when 'future'
      "Illegal attempt to assign via [index/key]. Not an assignable reference"
    else
      "Assigning to the hash 'my_hash' with an existing key 'one'"
    end
    fail_test("didn't find the failure") unless stderr.include?(expected_error_message)
  end
end
