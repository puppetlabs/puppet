test_name "should remove all empty subdirectory after tidying files"
confine :except, :platform => [ 'windows' ]

dir = "/tmp/"
subdir = "tidydir/"
file1 = "#{dir}tidy-test-1-#{Time.new.to_i}"
file2 = "#{dir}tidy-test-2-#{Time.new.to_i}"
file3 = "#{dir}tidy-test-3-#{Time.new.to_i}"

agents.each do |agent|

  step "clean up the system before we begin"
  on agent, "rm -rf #{dir}#{subdir}"
  step "create subdirectory"
  on agent, "mkdir #{dir}#{subdir}"
  step "create files to remove in subdirectory"
  on agent, "touch #{file1} #{file2} #{file3}"

  step "verify we can remove empty directories"
  on agent, puppet_resource("tidy", dir, 'recurse=2', 'matches="tidy*"', 'rmdirs=true')

  step "verify that the files are gone"
  on agent, "test -e #{file1}", :acceptable_exit_codes => [1]
  on agent, "test -e #{file2}", :acceptable_exit_codes => [1]
  on agent, "test -e #{file3}", :acceptable_exit_codes => [1]
  step "verify that the subdirectory is gone"
  on agent, "test -d #{subdir}", :acceptable_exit_codes => [1]

end
