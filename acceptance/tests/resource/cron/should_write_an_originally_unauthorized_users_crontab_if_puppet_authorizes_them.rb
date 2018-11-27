test_name "The crontab provider should be able to write an originally unauthorized user's crontab if Puppet authorizes them during the run" do
  # Our Linux + OSX platforms run crontab as root, which is always authorized. However,
  # AIX and Solaris run crontab as the given user so this test only makes sense for our
  # AIX and Solaris platforms.
  confine :to, :platform => /aix|solaris/

  tag 'audit:medium',
      'audit:unit'
  
  require 'puppet/acceptance/common_utils'
  extend Puppet::Acceptance::BeakerUtils
  extend Puppet::Acceptance::CronUtils
  extend Puppet::Acceptance::ManifestUtils

  agents.each do |agent|
    username = "pl#{rand(999999).to_i}"
    unauthorized_username = "pl#{rand(999999).to_i}"

    teardown do
      run_cron_on(agent, :remove, username)
      user_absent(agent, username)

      run_cron_on(agent, :remove, unauthorized_username)
      user_absent(agent, unauthorized_username)
    end

    step "Ensure that the test users exist" do
      user_present(agent, username)
      user_present(agent, unauthorized_username)
    end

    case agent['platform']
    when /aix/
      cron_deny_path = '/var/adm/cron/cron.deny'
    when /solaris/
      cron_deny_path = '/etc/cron.d/cron.deny'
    else
      fail_test "Cannot figure out the path of the cron.deny file for the #{agent['platform']} platform"
    end

    cron_deny_original_contents = nil
    step "Get the original contents of the cron.deny file" do
      cron_deny_original_contents = on(agent, "cat #{cron_deny_path}").stdout

      teardown do
        apply_manifest_on(agent, file_manifest(cron_deny_path, ensure: :present, content: cron_deny_original_contents))
      end
    end

    step "Add the unauthorized user to the cron.deny file" do
      on(agent, "echo #{unauthorized_username} >> #{cron_deny_path}")
    end

    step "Verify that the unauthorized user was added to the cron.deny file" do
      cron_deny_contents = on(agent, "cat #{cron_deny_path}").stdout

      assert_match(/^#{unauthorized_username}$/, cron_deny_contents, "Failed to add the unauthorized user to the cron.deny file")
    end

    step "Modify the unauthorized user's crontab with Puppet" do
      # The scenario we're testing here is:
      #   * An unrelated cron resource triggers the prefetch step, which will also
      #   prefetch the crontab of our unauthorized user. The latter prefetch should
      #   fail, instead returning an empty crontab file.
      #
      #   * Puppet authorizes our unauthorized user by removing them from the cron.deny
      #   file.
      #
      #   * A cron resource linked to our (originally) unauthorized user should now be able
      #   to write to that user's crontab file (assuming it requires the resource updating
      #   the cron.deny file)
      #
      # The following manifest replicates the above scenario. Note that we test this specific
      # scenario to ensure that the changes in PUP-9217 enforce backwards compatibility.
      manifest = [
        cron_manifest('first_entry', command: "ls", user: username),
        file_manifest(cron_deny_path, ensure: :present, content: cron_deny_original_contents),
        cron_manifest('second_entry', command: "ls", user: unauthorized_username),
      ].join("\n\n")

      apply_manifest_on(agent, manifest)
    end

    step "Verify that Puppet did modify the unauthorized user's crontab" do
      assert_matching_arrays(["* * * * * ls"], crontab_entries_of(agent, unauthorized_username), "Puppet did not modify the unauthorized user's crontab file")
    end
  end
end
