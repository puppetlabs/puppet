test_name "puppet should remove a crontab entry as expected"
confine :except, :platform => 'windows'

require 'puppet/acceptance/common_utils'
extend Puppet::Acceptance::CronUtils

agents.each do |host|
    step "ensure the user exist via puppet"
    setup host

    step "create the existing job by hand..."
    run_cron_on(host,:add,'tstuser',"* * * * * /bin/true")

    step "apply the resource on the host using puppet resource"
    on(host, puppet_resource("cron", "crontest", "user=tstuser",
                  "command=/bin/true", "ensure=absent")) do
      assert_match(/crontest\D+ensure:\s+removed/, stdout, "Didn't remove crobtab entry for tstuser on #{host}")
    end

    step "verify that crontab -l contains what you expected"
    run_cron_on(host, :list, 'tstuser') do
      assert_no_match(/\/bin\/true/, stderr, "Error: Found entry for tstuser on #{host}")
    end

end
