test_name "should remove only large files"
confine :except, :platform => [ 'windows' ]

dir = "/tmp/"
file1 = "#{dir}tidy-test-1-#{Time.new.to_i}"
file2 = "#{dir}tidy-test-2-#{Time.new.to_i}"
file3 = "#{dir}tidy-test-3-#{Time.new.to_i}"

agents.each do |agent|

  step "clean up the system before we begin"
  on agent, "rm -rf #{dir}/tidy-test-*"
  step "create some small files"
  on agent, "touch #{file1} #{file2}"
  step "create a 10MB file"
  on agent, "dd if=/dev/zero of=#{file3} bs=1024 count=10240"

  step "verify we can remove big files"
  on agent, puppet_resource("tidy", dir, 'recurse=1', 'size="5m"')

  step "verify that the small files still exist"
  on agent, "test -e #{file1}", :acceptable_exit_codes => [0]
  on agent, "test -e #{file2}", :acceptable_exit_codes => [0]
  step "verify that the big file was deleted"
  on agent, "test -e #{file3}", :acceptable_exit_codes => [1]

  step "clean up after ourselves"
  on agent, "rm -rf #{dir}/tidy-test-*"

end
