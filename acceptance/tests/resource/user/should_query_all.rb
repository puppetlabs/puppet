test_name "ensure that puppet queries the correct number of users"

agents.each do |host|
    users = []

    step "collect the list of known users via getent"
    on(host, "getent passwd") do
        stdout.each_line do |line|
            users << line.split(':')[0]
        end
    end

    step "collect the list of known users via puppet"
    on(host, puppet_resource('user')) do
        stdout.each_line do |line|
            name = ( line.match(/^user \{ '([^']+)'/) or next )[1]

            # OK: Was this name found in the list of users?
            if users.member? name then
                users.delete name
            else
                fail_test "user #{name} found by puppet, not by getent"
            end
        end
    end

    if users.length > 0 then
        fail_test "#{users.length} users found with getent, not puppet: #{users.join(', ')}"
    end
end
