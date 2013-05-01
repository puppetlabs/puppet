test_name "should remove all files in tmp directory that match glob"
confine :except, :platform => [ 'windows' ]

dir = "/tmp/"
file1 = "#{dir}tidy-test-1-#{Time.new.to_i}"
file2 = "#{dir}tidy-test-2-#{Time.new.to_i}"
file3 = "#{dir}tidy-test-3-#{Time.new.to_i}"

agents.each do |agent|

  step "clean up the system before we begin"
  on agent, "rm -rf #{dir}/tidy-test-*"
  step "create files to remove"
  on agent, "touch #{file1} #{file2} #{file3}"

  step "verify we can remove files"
  on agent, puppet_resource("tidy", dir, 'recurse=1', 'matches="tidy*"')

  step "verify that the files are gone"
  on agent, "test -e #{file1}", :acceptable_exit_codes => [1]
  on agent, "test -e #{file2}", :acceptable_exit_codes => [1]
  on agent, "test -e #{file3}", :acceptable_exit_codes => [1]

end
