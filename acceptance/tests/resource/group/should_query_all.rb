test_name "puppet resource should query all groups"

agents.each do |host|
    groups = {}

    step "collect the list of groups on #{host} with getent group"
    on(host, "getent group") do
        stdout.each_line do |line| groups[line[/^[^:]+/]] = 'getent' end
    end

    step "collect the list of groups on #{host} with puppet resource"
    on(host, puppet_resource('group')) do
        stdout.each_line do |line|
            match = line.match(/^group \{ '([^']+)'/)
            if match then
                name = match[1]

                if groups.include? name then
                    groups.delete name
                else
                    fail_test "group #{name} found by puppet, not getent"
                end
            end
        end
    end

    groups.keys.each do |name|
        fail_test "group #{name} found by getent, not puppet"
    end
end
