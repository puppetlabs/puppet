test_name "ticket 4622 filebucket diff test."
confine :except, :platform => 'windows'

def create_testfile(filename, contents)
  create_remote_file(agent, filename, "#{contents}")
end

def get_checksum_from_backup(filename, bucket_locale)
  on agent, puppet("filebucket backup #{filename} #{bucket_locale}"), :acceptable_exit_codes => [ 0, 2 ]
  output = result.stdout.strip.split(": ")
  checksum = output.last
  return checksum
end

def validate_diff(item_one, item_two, bucket_locale)
  on agent, puppet("filebucket diff #{item_one} #{item_two} #{bucket_locale}"), :acceptable_exit_codes => [ 0, 2 ]
  assert_match("-foo", result.stdout.strip)
  assert_match('+bar', result.stdout.strip)
  assert_match('+baz', result.stdout.strip)
end

step "Master: Start Puppet Master" do
  hostname = on(master, 'facter hostname').stdout.strip
  fqdn = on(master, 'facter fqdn').stdout.strip
  master_opts = {
    :main => {
      :dns_alt_names => "puppet,#{hostname},#{fqdn}",
    },
    :__service_args__ => {
      :bypass_service_script => true,
    },
  }

  with_puppet_running_on(master, master_opts) do
  agents.each do |agent|

    tmpfile = agent.tmpfile('testfile')
    remote_str = "--remote --server #{master}"
    local_str = "--local"

    teardown do
      step "Cleanup tmpfile"
      on(agent, "rm -f #{tmpfile}")
    end

    step "Create a tmp file with single line 'foo'"
    create_testfile(tmpfile,"foo")

    step "Backup the file using remote filebucket and get the checksum"
    remote_checksum_1 = get_checksum_from_backup(tmpfile, remote_str)

    step "Modify the tmpfile contents, remove line 'foo' and add lines 'bar' and 'baz'"
    create_testfile(tmpfile,"bar\nbaz")

    step "Backup the modified file using remote filebucket and get the new checksum"
    remote_checksum_2 = get_checksum_from_backup(tmpfile, remote_str)

    step "Find the filebucket diff of the two checksums and validate the output "
    validate_diff(remote_checksum_1, remote_checksum_2, remote_str)

    step "Find the filebucket diff of the first checksum and the local file and validate the output "
    validate_diff(remote_checksum_1, tmpfile, remote_str)

    step "Repeat above steps for local file bucket"

    step "Create a tmp file with single line 'foo'"
    create_testfile(tmpfile,"foo")

    step "Backup the file using local filebucket and get the checksum"
    local_checksum_1 = get_checksum_from_backup(tmpfile, local_str)

    step "Modify the tmpfile contents, remove line 'foo' and add lines 'bar' and 'baz'"
    create_testfile(tmpfile,"bar\nbaz")

    step "Backup the modified file using local filebucket and get the new checksum"
    local_checksum_2 = get_checksum_from_backup(tmpfile, local_str)

    step "Find the filebucket diff of the two checksums and validate the output "
    validate_diff(local_checksum_1, local_checksum_2, local_str)

    step "Find the filebucket diff of the first checksum and the local file and validate the output "
    validate_diff(local_checksum_1, tmpfile, local_str)

  end
  end
end
