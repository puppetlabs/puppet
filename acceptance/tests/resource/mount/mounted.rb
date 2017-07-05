test_name "mounted should create an entry in filesystem table and mount it"

confine :except, :platform => ['windows']
confine :except, :platform => /osx/ # See PUP-4823
confine :except, :platform => /solaris/ # See PUP-5201
confine :except, :platform => /^eos-/ # Mount provider not supported on Arista EOS switches
confine :except, :platform => /^cisco_/ # See PUP-5826
confine :except, :platform => /^huawei/ # See PUP-6126

tag 'audit:low',
    'audit:refactor',  # Use block style `test_name`
    'audit:acceptance' # Could be done at the integration (or unit) layer though
                       # actual changing of resources could irreparably damage a
                       # host running this, or require special permissions.

require 'puppet/acceptance/mount_utils'
extend Puppet::Acceptance::MountUtils

name = "pl#{rand(999999).to_i}"

agents.each do |agent|
  fs_file = filesystem_file(agent)
  fs_type = filesystem_type(agent)

  teardown do
    #(teardown) umount disk image
    on(agent, "umount /#{name}", :acceptable_exit_codes => (0..254))
    #(teardown) delete disk image
    if agent['platform'] =~ /aix/
      on(agent, "rmlv -f #{name}", :acceptable_exit_codes => (0..254))
    else
      on(agent, "rm /tmp/#{name}", :acceptable_exit_codes => (0..254))
    end
    #(teardown) delete mount point
    on(agent, "rm -fr /#{name}", :acceptable_exit_codes => (0..254))
    #(teardown) restore the fstab file
    on(agent, "mv /tmp/fs_backup_file #{fs_file}", :acceptable_exit_codes => (0..254))
  end

  #------- SETUP -------#
  step "(setup) backup #{fs_file} file"
  on(agent, "cp #{fs_file} /tmp/fs_backup_file", :acceptable_exit_codes => [0,1])

  step "(setup) create mount point"
  on(agent, "mkdir /#{name}", :acceptable_exit_codes => [0,1])

  step "(setup) create new filesystem to be mounted"
  create_filesystem(agent, name)

  #------- TESTS -------#
  step "create a mount with puppet (mounted)"
  if agent['platform'] =~ /aix/
    args = ['ensure=mounted',
            "fstype=#{fs_type}",
            "options='log=/dev/hd8'",
            "device=/dev/#{name}",
           ]
  else
    args = ['ensure=mounted',
            "fstype=#{fs_type}",
            'options=loop',
            "device=/tmp/#{name}",
           ]
  end

  on(agent, puppet_resource('mount', "/#{name}", args))

  step "verify entry in filesystem table"
  on(agent, "cat #{fs_file}") do |res|
    fail_test "didn't find the mount #{name}" unless res.stdout.include? "#{name}"
  end

  step "verify entry is mounted"
  on(agent, "mount") do |res|
    fail_test "didn't find the mount #{name} mounted" unless res.stdout.include? "#{name}"
  end
end
