test_name "puppet should remove a crontab entry based on command matching"

tmpuser = "pl#{rand(999999).to_i}"
tmpfile = "/tmp/cron-test-#{Time.new.to_i}"

cron = '# Puppet Name: crontest\n* * * * * /bin/true\n1 1 1 1 1 /bin/true\n'

create_user = "user { '#{tmpuser}': ensure => present, managehome => false }"
delete_user = "user { '#{tmpuser}': ensure => absent,  managehome => false }"

agents.each do |host|
    step "ensure the user exist via puppet"
    apply_manifest_on host, create_user

    step "create the existing job by hand..."
    run_cron_on(host,:add,tmpuser,"* * * * * /bin/true")

    step "Remove cron resource"
    on(host, puppet_resource("cron", "bogus", "user=#{tmpuser}",
                  "command=/bin/true", "ensure=absent")) do
      assert_match(/bogus\D+ensure: removed/, stdout, "Removing cron entry failed for #{tmpuser} on #{host}")
    end

    step "verify that crontab -l contains what you expected"
    run_cron_on(host,:list,tmpuser) do
        count = stdout.scan("/bin/true").length
        fail_test "found /bin/true the wrong number of times (#{count})" unless count == 0
    end

    step "remove the crontab file for that user"
    run_cron_on(host,:remove,tmpuser)

    step "remove the user from the system"
    apply_manifest_on host, delete_user
end
