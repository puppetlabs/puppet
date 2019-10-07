test_name "Be able to execute multi-line commands (#9996)"
confine :except, :platform => 'windows'
tag 'audit:high',
    'audit:refactor',  # Use block style `test_name`
    'audit:acceptance'

agents.each do |agent|
  temp_file_name = agent.tmpfile('9996-multi-line-commands')

  test_manifest = <<HERE
exec { "test exec":
      command =>  "/bin/echo '#Test' > #{temp_file_name};
                   /bin/echo 'bob' >> #{temp_file_name};"
}
HERE

  expected_results = <<HERE
#Test
bob
HERE

  on(agent, "rm -f #{temp_file_name}")

  apply_manifest_on agent, test_manifest

  on(agent, "cat #{temp_file_name}") do
    assert_equal(expected_results, stdout, "Unexpected result for host '#{agent}'")
  end

  on(agent, "rm -f #{temp_file_name}")
end
