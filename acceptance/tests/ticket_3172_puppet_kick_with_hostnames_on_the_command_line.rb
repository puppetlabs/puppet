test_name "#3172: puppet kick with hostnames on the command line"
step "verify that we trigger our host"

target = 'working.example.org'
on(agents, puppet_kick(target), :acceptable_exit_codes => [3]) {
  fail_test "didn't trigger #{target}" unless stdout.include? "Triggering #{target}"
}
