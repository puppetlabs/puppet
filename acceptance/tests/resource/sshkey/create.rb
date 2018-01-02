test_name "(PUP-5508) Should add an SSH key to the correct ssh_known_hosts file on OS X/macOS" do
# TestRail test case C93370

tag 'audit:medium',
    'audit:acceptance' # Could be done at the integration (or unit) layer though
                       # actual changing of resources could irreparably damage a
                       # host running this, or require special permissions.

confine :to, :platform => /osx/

keyname = "pl#{rand(999999).to_i}"

# FIXME: This is bletcherous
macos_version = fact_on(agent, "os.macosx.version.major")
if ["10.9","10.10"].include? macos_version
  ssh_known_hosts = '/etc/ssh_known_hosts'
else
  ssh_known_hosts = '/etc/ssh/ssh_known_hosts'
end

teardown do
  puts "Restore the #{ssh_known_hosts} file"
  agents.each do |agent|
    # Is it present?
    rc = on(agent, "[ -e /tmp/ssh_known_hosts ]",
            :accept_all_exit_codes => true)
    if rc.exit_code == 0
      # It's present, so restore the original
      on(agent, "mv -fv /tmp/ssh_known_hosts #{ssh_known_hosts}",
         :accept_all_exit_codes => true)
    else
      # It's missing, which means there wasn't one to backup; just
      # delete the one we laid down
      on(agent, "rm -fv #{ssh_known_hosts}",
         :accept_all_exit_codes => true)
    end
  end
end

#------- SETUP -------#
step "Backup #{ssh_known_hosts} file, if present" do
  # The 'cp' might fail because the source file doesn't exist
  on(agent, "cp -fv #{ssh_known_hosts} /tmp/ssh_known_hosts",
     :acceptable_exit_codes => [0,1])
end

#------- TESTS -------#
step 'Verify that the default file is empty or non-existent' do
  # Is it even there?
  rc = on(agent, "[ ! -e #{ssh_known_hosts} ]",
          :acceptable_exit_codes => [0, 1])
  if rc.exit_code == 1 
    # If it's there, it should be empty
    on(agent, "cat #{ssh_known_hosts}") do |res|
      fail_test "Default #{ssh_known_hosts} file not empty" \
        unless stdout.empty?
    end
  end
end

step "Add an sshkey to the default file" do
  args = [
          "ensure=present",
          "key=how_about_the_key_of_c",
          "type=ssh-rsa",
         ]
  on(agent, puppet_resource("sshkey", "#{keyname}", args))
end

step 'Verify the new entry in the default file' do
  on(agent, "cat #{ssh_known_hosts}") do |rc|
    fail_test "Didn't find the ssh_known_host entry for #{keyname}" \
      unless stdout.include? "#{keyname}"
  end
end

end
