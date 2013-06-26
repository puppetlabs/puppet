test_name "puppet should match existing job"
confine :except, :platform => 'windows'

require 'puppet/acceptance/common_utils'
extend Puppet::Acceptance::CronUtils

agents.each do |host|
    step "ensure the user exist via puppet"
    setup host

    step "Create the existing cron job by hand..."
    run_cron_on(host,:add,'tstuser',"* * * * * /bin/true")

    step "Apply the resource on the host using puppet resource"
    on(host, puppet_resource("cron", "crontest", "user=tstuser",
                  "command=/bin/true", "ensure=present")) do
      assert_match(/present/, stdout, "Failed creating crontab for tstuser on #{host}")
    end

    step "Verify that crontab -l contains what you expected"
    run_cron_on(host, :list, 'tstuser') do
      assert_match(/\* \* \* \* \* \/bin\/true/, stdout, "Did not find crontab for tstuser on #{host}")
    end
end
