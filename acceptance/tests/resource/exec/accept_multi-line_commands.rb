test_name "Be able to execute multi-line commands (#9996)"

temp_file_name = "/tmp/9996-multi-line-commands.#{$$}"
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

on agents, "rm -f #{temp_file_name}"

apply_manifest_on agents, test_manifest

on(agents, "cat #{temp_file_name}").each do |result|
  assert_equal(expected_results, "#{result.stdout}", "Unexpected result for host '#{result.host}'")
end

on agents, "rm -f #{temp_file_name}"
