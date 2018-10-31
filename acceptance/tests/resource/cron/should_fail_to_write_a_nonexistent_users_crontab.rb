test_name "The crontab provider should fail to write a nonexistent user's crontab" do
  confine :except, :platform => 'windows'
  confine :except, :platform => /^eos-/ # See PUP-5500
  confine :except, :platform => /^fedora-28/
  tag 'audit:medium',
      'audit:unit'
  
  require 'puppet/acceptance/common_utils'
  extend Puppet::Acceptance::BeakerUtils
  extend Puppet::Acceptance::CronUtils
  extend Puppet::Acceptance::ManifestUtils

  agents.each do |agent|
    nonexistent_username = "pl#{rand(999999).to_i}"

    teardown do
      user_absent(agent, nonexistent_username)
    end

    step "Ensure that the nonexistent user does not exist" do
      user_absent(agent, nonexistent_username)
    end

    step "Create the nonexistent user's crontab entries with Puppet" do
      manifest = cron_manifest('second_entry', command: "ls", user: nonexistent_username)
      apply_manifest_on(agent, manifest, expect_failures: true)
    end
  end
end
