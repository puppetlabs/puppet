test_name "should delete an entry in filesystem table and unmount it"

confine :except, :platform => ['windows']

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

  step "(setup) create disk image"
  on(agent, "dd if=/dev/zero of=/tmp/#{name} count=10240", :acceptable_exit_codes => [0,1])
  on(agent, "yes | mkfs -t ext3 -q /tmp/#{name}")

  step "(setup) create mount point"
  on(agent, "mkdir /#{name}", :acceptable_exit_codes => [0,1])

  step "(setup) ensure loop kernel module is installed"
  on(agent, "modprobe loop", :acceptable_exit_codes => (0..254))

  step "(setup) add entry to filesystem table"
  on(agent, "echo '/tmp/#{name}  /#{name}  ext3  loop  0  0' >> #{fstab}")

  step "(setup) mount entry"
  on(agent, "mount /#{name}")

  #------- TESTS -------#
  step "destroy a mount with puppet (absent)"
  args = ['ensure=absent',
          "device='/tmp/#{name}'"
         ]
  on(agent, puppet_resource('mount', "/#{name}", args))

  step "verify entry removed from filesystem table"
  on(agent, "cat #{fstab}") do |res|
    fail_test "found the mount #{name}" if res.stdout.include? "#{name}"
  end

  step "verify entry is not mounted"
  on(agent, "mount") do |res|
    fail_test "found the mount #{name} mounted" if res.stdout.include? "#{name}"
  end
end
