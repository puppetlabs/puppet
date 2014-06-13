test_name "defined should create an entry in filesystem table"

confine :except, :platform => ['windows']

fstab = '/etc/fstab'
name = "pl#{rand(999999).to_i}"
mount = "/tmp/#{name}"

agents.each do |agent|
  teardown do
    #(teardown) restore the fstab file
    on(agent, "mv /tmp/fstab #{fstab}", :acceptable_exit_codes => [0,1])
    #(teardown) delete mount point
    on(agent, "rm -fr /tmp/#{name}", :acceptable_exit_codes => [0,1])
  end

  #------- SETUP -------#
  step "(setup) backup fstab file"
  on(agent, "cp #{fstab} /tmp/fstab", :acceptable_exit_codes => [0,1])

  #------- TESTS -------#
  step "create a mount with puppet (defined)"
  args = ['ensure=defined',
          "device='/tmp/#{name}'"
         ]
  on(agent, puppet_resource('mount', "/tmp/#{name}", args))

  step "verify entry in filesystem table"
  on(agent, "cat #{fstab}")  do |res|
    fail_test "didn't find the mount #{name}" unless stdout.include? "#{name}"
  end

end
