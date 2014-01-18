test_name "puppet should update existing crontab entry"
confine :except, :platform => 'windows'

require 'puppet/acceptance/common_utils'
extend Puppet::Acceptance::CronUtils

agents.each do |host|
    step "making_sure the user exist via puppet"
    setup host

    step "create the existing job by hand..."
    run_cron_on(host,:add,'tstuser',"* * * * * /bin/true")

    step "verify that crontab -l contains what you expected"
    run_cron_on(host,:list,'tstuser') do
      assert_match(/\* \* \* \* \* \/bin\/true/, stdout, "Didn't find correct crobtab entry for tstuser on #{host}")
    end

    step "apply the resource change on the host"
    on(host, puppet_resource("cron", "crontest", "user=tstuser", "command=/bin/true", "making_sure=present", "hour='0-6'")) do
        assert_match(/hour\s+=>\s+\['0-6'\]/, stdout, "Modifying cron entry failed for tstuser on #{host}")
    end

    step "verify that crontab -l contains what you expected"
    run_cron_on(host,:list,'tstuser') do
      assert_match(/\* 0-6 \* \* \* \/bin\/true/, stdout, "Didn't find correctly modified time entry in crobtab entry for tstuser on #{host}")
    end
end
