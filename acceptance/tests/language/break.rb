test_name 'C98162 - Validate `break` terminates execution in a block of code' do

tag 'audit:low',
    'audit:unit',   # This is testing core ruby functionality that is covered by
                    # existing spec tests.
    'audit:delete'

  agents.each do |agent|

    step 'apply class with break' do
      manifest =<<EOS
class break_test(
){

  $data = ["foo", "bar", "baz"]
  $secret_word = "foo"

  notify{ "The secret word is: $secret_word": }
  $data.each |String $data_point| {
    if $data_point == $secret_word {
      break()
    }
    notify{ "This message should not contain the secret word: $data_point": }
  }
  notify{ 'You should see this message': }
}

include break_test
EOS
      apply_manifest_on(agent, manifest) do |result|
        assert_match(/The secret word is: foo/, result.stdout)
        assert_no_match(/This message should not contain the secret word: foo/, result.output)
        assert_match(/You should see this/, result.stdout)
      end
    end

  end

end
