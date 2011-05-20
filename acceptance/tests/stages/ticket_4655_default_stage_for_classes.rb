test_name "#4655: Allow setting the default stage for parameterized classes"

temp_file_name = "/tmp/4655-stage-in-parameterized-class.#{$$}"
test_manifest = <<HERE
stage { one: before => Stage[two] }
stage { two: before => Stage[three] }
stage { three: before => Stage[main] }

class in_one {
  exec { "echo 'in_one' > #{temp_file_name}":
    path => '/usr/bin:/bin',
  }
}
class { in_one: stage => "one" }

class in_two( $stage=two ){
  exec { "echo 'in_two' >> #{temp_file_name}":
    path => '/usr/bin:/bin',
  }
}
class { in_two: }

class in_three {
  exec { "echo 'in_three' >> #{temp_file_name}":
    path => '/usr/bin:/bin',
  }
}
class { "in_three": stage => "three" }
HERE

expected_results = "in_one
in_two
in_three
"
apply_manifest_on agents, test_manifest

on(agents, "cat #{temp_file_name}").each do |result|
    assert_equal(expected_results, "#{result.stdout}", "Unexpected result for host '#{result.host}'")
end
