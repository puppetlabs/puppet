test_name "puppet should remove a crontab entry based on command matching"

tmpuser = "cron-test-#{Time.new.to_i}"
tmpfile = "/tmp/cron-test-#{Time.new.to_i}"

cron = '# Puppet Name: crontest\n* * * * * /bin/true\n1 1 1 1 1 /bin/true\n'

create_user = "user { '#{tmpuser}': ensure => present, managehome => false }"
delete_user = "user { '#{tmpuser}': ensure => absent,  managehome => false }"

agents.each do |host|
    step "ensure the user exist via puppet"
    apply_manifest_on host, create_user

    step "create the existing job by hand..."
    on host, "printf '#{cron}' | crontab -u #{tmpuser} -"

    step "apply the resource change on the host"
    on(host, puppet_resource("cron", "bogus", "user=#{tmpuser}",
                  "command=/bin/true", "ensure=absent")) do
        fail_test "didn't see the output we expected..." unless
            stdout.include? 'removed'
    end

    step "verify that crontab -l contains what you expected"
    on host, "crontab -l -u #{tmpuser}" do
        count = stdout.scan("/bin/true").length
        fail_test "found /bin/true the wrong number of times (#{count})" unless count == 1
    end

    step "remove the crontab file for that user"
    on host, "crontab -r -u #{tmpuser}"

    step "remove the user from the system"
    apply_manifest_on host, delete_user
end
