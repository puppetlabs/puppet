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
        fail_test "didn't find the content in the crontab" unless
            stdout.include? '* * * * * /bin/true'
    end

    step "apply the resource change on the host"
    on(host, puppet_resource("cron", "crontest", "user=#{tmpuser}",
                  "command=/bin/true", "ensure=present", "hour='0-6'")) do
        fail_test "didn't update the time as expected" unless
            stdout.include? "hour => ['0-6']"
    end

    step "verify that crontab -l contains what you expected"
    run_cron_on(host,:list,tmpuser) do
        fail_test "didn't find the content in the crontab" unless
            stdout.include? '* 0-6 * * * /bin/true'
    end

    step "remove the crontab file for that user"
    run_cron_on(host,:remove,tmpuser)

    step "remove the user from the system"
    apply_manifest_on host, delete_user
end
