test_name "ticket 4622 filebucket diff test."
confine :except, :platform => 'windows'
skip_test 'skip test, no non-Windows agents specified' if agents.empty?

tag 'audit:medium',
    'audit:integration',
    'audit:refactor',    # look into combining with ticket_6541_invalid_filebucket_files.rb
                         # Use block style `test_run`
    'server'

def get_checksum_from_backup_on(host, filename, bucket_locale)
  on host, puppet("filebucket backup #{filename} #{bucket_locale}"), :acceptable_exit_codes => [ 0, 2 ]
  output = result.stdout.strip.split(": ")
  checksum = output.last
  return checksum
end

def validate_diff_on(host, item_one, item_two, bucket_locale)
  on host, puppet("filebucket diff #{item_one} #{item_two} #{bucket_locale}"), :acceptable_exit_codes => [ 0, 2 ]
  assert_match(/[-<] ?foo/, result.stdout.strip)
  assert_match(/[+>] ?bar/, result.stdout.strip)
  assert_match(/[+>] ?baz/, result.stdout.strip)
end

step "Master: Start Puppet Master" do
  with_puppet_running_on(master, {}) do
    agents.each do |agent|

      if on(agent, facter("fips_enabled")).stdout =~ /true/
        # We do not want to do a skip_test here as that aborts the tests across all targets
        # and the whole test gets skipped even if it will succeed on any non-fips platforms
        puts "Skipping test on platforms in fips mode - (remote) filebucket is not supported"
        next
      end

      tmpfile = agent.tmpfile('testfile')
      remote_str = "--remote --server #{master}"
      local_str = "--local"

      teardown do
        step "Cleanup tmpfile"
        on(agent, "rm -f #{tmpfile}")
      end

      step "Create a tmp file with single line 'foo'"
      create_remote_file(agent, tmpfile, "foo")

      step "Backup the file using remote filebucket and get the checksum"
      remote_checksum_1 = get_checksum_from_backup_on(agent, tmpfile, remote_str)

      step "Modify the tmpfile contents, remove line 'foo' and add lines 'bar' and 'baz'"
      create_remote_file(agent, tmpfile, "bar\nbaz")

      step "Backup the modified file using remote filebucket and get the new checksum"
      remote_checksum_2 = get_checksum_from_backup_on(agent, tmpfile, remote_str)

      step "Find the filebucket diff of the two checksums and validate the output "
      validate_diff_on(agent, remote_checksum_1, remote_checksum_2, remote_str)

      step "Find the filebucket diff of the first checksum and the local file and validate the output "
      validate_diff_on(agent, remote_checksum_1, tmpfile, remote_str)

      step "Repeat above steps for local file bucket"

      step "Create a tmp file with single line 'foo'"
      create_remote_file(agent, tmpfile, "foo")

      step "Backup the file using local filebucket and get the checksum"
      local_checksum_1 = get_checksum_from_backup_on(agent, tmpfile, local_str)

      step "Modify the tmpfile contents, remove line 'foo' and add lines 'bar' and 'baz'"
      create_remote_file(agent, tmpfile, "bar\nbaz")

      step "Backup the modified file using local filebucket and get the new checksum"
      local_checksum_2 = get_checksum_from_backup_on(agent, tmpfile, local_str)

      step "Find the filebucket diff of the two checksums and validate the output "
      validate_diff_on(agent, local_checksum_1, local_checksum_2, local_str)

      step "Find the filebucket diff of the first checksum and the local file and validate the output "
      validate_diff_on(agent, local_checksum_1, tmpfile, local_str)

    end
  end
end
