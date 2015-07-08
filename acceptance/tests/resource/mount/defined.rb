test_name "defined should create an entry in filesystem table"

confine :except, :platform => ['windows']
confine :except, :platform => /osx/ # See PUP-4823

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

  #------- TESTS -------#
  step "create a mount with puppet (defined)"
  args = ['ensure=defined',
          'fstype=ext3',
          "device='/tmp/#{name}'"
         ]
  on(agent, puppet_resource('mount', "/#{name}", args))

  step "verify entry in filesystem table"
  on(agent, "cat #{fstab}")  do |res|
    fail_test "didn't find the mount #{name}" unless stdout.include? "#{name}"
  end

end
