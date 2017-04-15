test_name "should leave all files in tmp directory that don't match glob"
confine :except, :platform => [ 'windows' ]

dir = "/tmp/"
file1 = "#{dir}tidy-test-1-#{Time.new.to_i}"
file2 = "#{dir}tidy-test-2-#{Time.new.to_i}"
file3 = "#{dir}tidy-test-3-#{Time.new.to_i}"

agents.each do |agent|

  step "clean up the system before we begin"
  on agent, "rm -rf #{dir}/tidy-test-*"
  step "create files to leave behind"
  on agent, "touch #{file1} #{file2} #{file3}"

  step "verify we can correctly leave behind files"
  on agent, puppet_resource("tidy", dir, 'recurse=1', 'matches="foo*"')

  step "verify that the files are still present"
  on agent, "test -e #{file1}", :acceptable_exit_codes => [0]
  on agent, "test -e #{file2}", :acceptable_exit_codes => [0]
  on agent, "test -e #{file3}", :acceptable_exit_codes => [0]

  step "clean up the system before we finish"
  on agent, "rm -rf #{dir}/tidy-test-*"

end
