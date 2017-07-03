test_name 'C98162 - Validate `return` immediately returns from a block of code' do

tag 'audit:medium',
    'audit:unit'

  agents.each do |agent|

    step 'apply class with return' do
      manifest =<<EOS
class return_test(
){
  $data = ["foo", "bar", "baz"]
  $secret_word = "foo"

  notify{ "The secret word is: $secret_word": }
  $data.each |String $data_point| {
    if $data_point == $secret_word {
      return($secret_word)
      notify{ 'You should not see this message': }
    }
    notify{ 'You should not see this message either': }
  }
  notify{ "Is this the secret word: $secret_word": }
}

include return_test
EOS
      apply_manifest_on(agent, manifest) do |result|
        # In a class context, `return` should return from the class.
        # So, no code below the return should be executed in the above
        # manifest.
        assert_match(/The secret word is: foo/, result.stdout)
        assert_no_match(/You should not see this/, result.output)
        assert_no_match(/Is this the secret word: foo/, result.stdout)
      end
    end

    step 'apply function with return' do
      manifest =<<EOS
function example($x) {
  $secret_word = "foo"
  if $x == $secret_word {
    return($secret_word)
    notify{ "$x in function": message => 'You should not see this message', }
  }
  return('')
  notify{ "$x in function": message => 'You should not see this message', }
}
class return_test(
){
  $data = ["foo", "bar", "baz"]
  $secret_word = "foo"

  notify{ "The secret word is: $secret_word": }
  $data.each |String $data_point| {
    $answer = example($data_point)
    notify{ $data_point: message => "Is this the secret word: $answer", }
  }
}

include return_test
EOS
      apply_manifest_on(agent, manifest) do |result|
        # In a function context, `return` should return the specified
        # value from the function.
        # So, the code below the return in the function should not be
        # executed, but the class `notify` statements should be called.
        assert_match(/The secret word is: foo/, result.stdout)
        assert_no_match(/You should not see this/, result.output)
        assert_match(/Is this the secret word: foo/, result.stdout)
      end
    end

  end

end
