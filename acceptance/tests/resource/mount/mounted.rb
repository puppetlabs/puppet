test_name "mounted should create an entry in filesystem table and mount it"

confine :except, :platform => ['windows']

fstab = '/etc/fstab'
name = "pl#{rand(999999).to_i}"

agents.each do |agent|
  teardown do
    #(teardown) restore the fstab file
    on(agent, "mv /tmp/fstab #{fstab}", :acceptable_exit_codes => [0,1])
    #(teardown) umount disk image
    on(agent, "umount /#{name}", :acceptable_exit_codes => [0,1])
    #(teardown) delete disk image
    on(agent, "rm /tmp/#{name}", :acceptable_exit_codes => [0,1])
    #(teardown) delete mount point
    on(agent, "rm -fr /#{name}", :acceptable_exit_codes => [0,1])
  end

  #------- SETUP -------#
  step "(setup) backup fstab file"
  on(agent, "cp #{fstab} /tmp/fstab", :acceptable_exit_codes => [0,1])

  step "(setup) create disk image"
  on(agent, "dd if=/dev/zero of=/tmp/#{name} count=10240", :acceptable_exit_codes => [0,1])
  on(agent, "yes | mkfs -t ext3 -q /tmp/#{name}")

  step "(setup) create mount point"
  on(agent, "mkdir /#{name}", :acceptable_exit_codes => [0,1])

  #------- TESTS -------#
  step "create a mount with puppet (mounted)"
  args = ['ensure=mounted',
          'fstype=ext3',
          'options=loop',
          "device='/tmp/#{name}'"
         ]
  on(agent, puppet_resource('mount', "/#{name}", args))

  step "verify entry in filesystem table"
  on(agent, "cat #{fstab}") do |res|
    fail_test "didn't find the mount #{name}" unless res.stdout.include? "#{name}"
  end

  step "verify entry is mounted"
  on(agent, "mount") do |res|
    fail_test "didn't find the mount #{name} mounted" unless res.stdout.include? "#{name}"
  end
end
