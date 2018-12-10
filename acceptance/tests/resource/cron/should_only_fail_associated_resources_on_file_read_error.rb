test_name "The crontab provider should fail to evaluate only the resources associated with an unreadable crontab file" do
  confine :except, :platform => 'windows'
  confine :except, :platform => /^eos-/ # See PUP-5500
  tag 'audit:medium',
      'audit:unit'

  require 'puppet/acceptance/common_utils'
  extend Puppet::Acceptance::BeakerUtils
  extend Puppet::Acceptance::CronUtils
  extend Puppet::Acceptance::ManifestUtils

  agents.each do |agent|
    username = "pl#{rand(999999).to_i}"
    failed_username = "pl#{rand(999999).to_i}"
    step "Create the users" do
      user_present(agent, username)
      user_present(agent, failed_username)

      teardown do
        run_cron_on(agent, :remove, username)
        user_absent(agent, username)

        user_absent(agent, failed_username)
      end
    end

    crontab_exe = nil
    step "Find the crontab executable" do
      crontab_exe = on(agent, "which crontab").stdout.chomp
    end

    stub_crontab_bin_dir = nil
    stub_crontab_exe = nil
    step "Create the stub crontab executable that triggers the read error for the failed user" do
      stub_crontab_bin_dir = agent.tmpdir("stub_crontab_bin_dir")
      stub_crontab_exe = "#{stub_crontab_bin_dir}/crontab"

      # On Linux and OSX, we read a user's crontab by running crontab -u <username>,
      # where the crontab command is run as root. However on AIX/Solaris, we read a
      # user's crontab by running the crontab command as that user. Thus our mock
      # crontab executable needs to check if we're reading our failed user's crontab
      # (Linux and OSX) OR running crontab as our failed user (AIX and Solaris) before
      # triggering the FileReadError
      stub_crontab_exe_script = <<-SCRIPT
#!/usr/bin/env bash

if [[ "$@" =~ #{failed_username} || "`id`" =~ #{failed_username} ]]; then
  echo "Mocking a FileReadError for the #{failed_username} user's crontab!"
  exit 1
fi

#{crontab_exe} $@
SCRIPT

      create_remote_file(agent, stub_crontab_exe, stub_crontab_exe_script)

      on(agent, "chmod 777 #{stub_crontab_bin_dir}")
      on(agent, "chmod 777 #{stub_crontab_exe}")
    end

    path_env_var = nil
    step "Get the value of the PATH environment variable" do
      path_env_var = on(agent, "echo $PATH").stdout.chomp
    end

    puppet_result = nil
    step "Add some cron entries with Puppet" do
      # We delete our mock crontab executable here to ensure that Cron[second_entry]'s
      # evaluation fails because of the FileReadError raised in the prefetch
      # step. Otherwise, Cron[second_entry]'s evaluation will fail at the write step
      # because Puppet would still be invoking our mock crontab executable, which would
      # pass the test on an agent that swallows FileReadErrors in the cron provider's
      # prefetch step.
      manifest = [
        cron_manifest('first_entry', command: "ls", user: username),
        file_manifest(stub_crontab_exe, ensure: :absent),
        cron_manifest('second_entry', command: "ls", user: failed_username),
      ].join("\n\n")
      manifest_file = agent.tmpfile("crontab_overwrite_manifest")
      create_remote_file(agent, manifest_file, manifest)

      # We need to run a script here instead of a command because:
      #   * We need to cd into a directory that our user can access. Otherwise, bash will
      #   fail to execute stub_crontab_exe on AIX and Solaris because we run crontab
      #   as the given user, and the given user does not have access to Puppet's cwd.
      #
      #   * We also need to pass-in our PATH to Puppet since it contains stub_crontab_bin_dir.
      apply_crontab_overwrite_manifest = agent.tmpfile("apply_crontab_overwrite_manifest")
      script = <<-SCRIPT
#!/usr/bin/env bash

cd #{stub_crontab_bin_dir} && puppet apply #{manifest_file}
SCRIPT
      create_remote_file(agent, apply_crontab_overwrite_manifest, script)
      on(agent, "chmod a+x #{apply_crontab_overwrite_manifest}")

      puppet_result = on(agent, "bash #{apply_crontab_overwrite_manifest}", environment: { PATH: "#{stub_crontab_bin_dir}:#{path_env_var}" })
    end

    step "Verify that Puppet fails a Cron resource associated with an unreadable crontab file" do
      assert_match(/Cron.*second_entry/, puppet_result.stderr, "Puppet does not fail a Cron resource associated with an unreadable crontab file")
    end

    step "Verify that Puppet does not fail a Cron resource associated with a readable crontab file" do
      assert_no_match(/Cron.*first_entry/, puppet_result.stderr, "Puppet fails a Cron resource associated with a readable crontab file")
    end

    step "Verify that Puppet successfully evaluates a Cron resource associated with a readable crontab file" do
      assert_match(/Cron.*first_entry/, puppet_result.stdout, "Puppet fails to evaluate a Cron resource associated with a readable crontab file")
    end

    step "Verify that Puppet did update the readable crontab file with the Cron resource" do
      assert_matching_arrays(["* * * * * ls"], crontab_entries_of(agent, username), "Puppet fails to update a readable crontab file with the specified Cron entry")
    end
  end
end
