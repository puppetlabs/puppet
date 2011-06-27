test_name "puppet should update existing crontab entry"

tmpuser = "pl#{rand(999999).to_i}"
tmpfile = "/tmp/cron-test-#{Time.new.to_i}"

create_user = "user { '#{tmpuser}': ensure => present, managehome => false }"
delete_user = "user { '#{tmpuser}': ensure => absent,  managehome => false }"

agents.each do |host|
    step "ensure the user exist via puppet"
    apply_manifest_on host, create_user

    step "create the existing job by hand..."
    run_cron_on(host,:add,tmpuser,"* * * * * /bin/true")

    step "verify that crontab -l contains what you expected"
    run_cron_on(host,:list,tmpuser) do
      assert_match(/\* \* \* \* \* \/bin\/true/, stdout, "Didn't find correct crobtab entry for #{tmpuser} on #{host}")
    end

    step "apply the resource change on the host"
    on(host, puppet_resource("cron", "crontest", "user=#{tmpuser}",
      "command=/bin/true", "ensure=present", "hour='0-6'")) do
        assert_match(/hour\s+=>\s+\['0-6'\]/, stdout, "Modifying cron entry failed for #{tmpuser} on #{host}")
    end

    step "verify that crontab -l contains what you expected"
    run_cron_on(host,:list,tmpuser) do
      assert_match(/\* 0-6 \* \* \* \/bin\/true/, stdout, "Didn't find correctly modified time entry in crobtab entry for #{tmpuser} on #{host}")
    end

    step "remove the crontab file for that user"
    run_cron_on(host,:remove,tmpuser)

    step "remove the user from the system"
    apply_manifest_on host, delete_user
end
