test_name "the path statement should work to locate commands"

file = "/tmp/touched-should-set-path-#{Time.new.to_i}"

step "clean up the system for the test"
on agents, "rm -f #{file}"

step "invoke the exec resource with a path set"
on(agents, puppet_resource('exec', 'test',
              "command='touch #{file}'", 'path="/bin:/usr/bin"'))

step "verify that the files were created"
on agents, "test -f #{file}"

step "clean up the system after testing"
on agents, "rm -f #{file}"
