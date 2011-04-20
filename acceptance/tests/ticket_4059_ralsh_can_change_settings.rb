test_name "#4059: ralsh can change settings"

target = "/tmp/hosts-#4059"
content = "host example.com ensure=present ip=127.0.0.1 target=#{target}"

step "cleanup the target file"
on agents, "rm -f #{target}"

step "run the resource agent"
on(agents, puppet_resource(content)) do
  stdout.index('Host[example.com]/ensure: created') or
    fail_test("missing notice about host record creation")
end
on(agents, "cat #{target}") do
  stdout =~ /^127\.0\.0\.1\s+example\.com/ or
    fail_test("missing host record in #{target}")
end

step "cleanup at the end of the test"
on agents, "rm -f #{target}"
