test_name "#4655: Allow setting the default stage for parameterized classes"

tag 'audit:low',      # basic language functionality for relatively little used concept
    'audit:refactor', # Use block style `test_name`
    'audit:unit'

agents.each do |agent|
  temp_file_name = agent.tmpfile('4655-stage-in-parameterized-class')
test_manifest = <<HERE
stage { one: before => Stage[two] }
stage { two: before => Stage[three] }
stage { three: before => Stage[main] }

class in_one {
  exec { "#{agent.echo('in_one', false)} > #{temp_file_name}":
    path => '#{agent.path}',
  }
}
class { in_one: stage => "one" }

class in_two( $stage=two ){
  exec { "#{agent.echo('in_two', false)} >> #{temp_file_name}":
    path => '#{agent.path}',
  }
}
class { in_two: }

class in_three {
  exec { "#{agent.echo('in_three', false)} >> #{temp_file_name}":
    path => '#{agent.path}',
  }
}
class { "in_three": stage => "three" }
HERE

  expected_results = "in_one
in_two
in_three
"
  apply_manifest_on agent, test_manifest

  on(agent, "cat #{temp_file_name}") do
    # echo on windows adds \r\n, so do dotall regexp match
    assert_match(/in_one\s*in_two\s*\in_three/m, stdout, "Unexpected result for host '#{agent}'")
  end
end
