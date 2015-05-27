test_name "should modify an entry in filesystem table"

confine :except, :platform => ['windows']

fstab = '/etc/fstab'
name = "pl#{rand(999999).to_i}"
new_name = "pl#{rand(999999).to_i}"

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

  step "(setup) add entry to filesystem table"
  on(agent, "echo '/tmp/#{name}  /#{name}  ext3  loop  0  0' >> #{fstab}")

  step "(setup) mount entry"
  on(agent, "mount /#{name}")

  #------- TESTS -------#
  step "modify a mount with puppet (defined)"
  args = ['ensure=defined',
          'fstype=bogus',
          "device='/tmp/#{name}'"
         ]
  on(agent, puppet_resource('mount', "/#{name}", args))

  step "verify entry is updated in filesystem table"
  on(agent, "cat #{fstab}") do |res|
    fail_test "attributes not updated for the mount #{name}" unless res.stdout.include? "bogus"
  end

end
