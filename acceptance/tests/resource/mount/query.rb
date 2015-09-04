test_name "should be able to find an existing filesystem table entry"

confine :except, :platform => ['windows']
confine :except, :platform => /solaris/

fstab = '/etc/fstab'
name = "pl#{rand(999999).to_i}"

agents.each do |agent|
  teardown do
    #(teardown) restore the fstab file
    on(agent, "mv /tmp/fstab #{fstab}", :acceptable_exit_codes => (0..254))
    #(teardown) umount disk image
    on(agent, "umount /#{name}", :acceptable_exit_codes => (0..254))
    #(teardown) delete disk image
    on(agent, "rm /tmp/#{name}", :acceptable_exit_codes => (0..254))
    #(teardown) delete mount point
    on(agent, "rm -fr /#{name}", :acceptable_exit_codes => (0..254))
  end

  #------- SETUP -------#
  step "(setup) backup fstab file"
  on(agent, "cp #{fstab} /tmp/fstab", :acceptable_exit_codes => [0,1])

  step "(setup) add entry to filesystem table"
  on(agent, "echo '/tmp/#{name}  /#{name}  0  0' >> #{fstab}")

  #------- TESTS -------#
  step "verify mount with puppet"
  on(agent, puppet_resource('mount', "/#{name}")) do |res|
    fail_test "didn't find the mount #{name}" unless res.stdout.include? "#{name}"
  end

end
