test_name "puppet apply should create a file and report an MD5"

file = "/tmp/hello.world.#{Time.new.to_i}.txt"
manifest = "file{'#{file}': content => 'test'}"

step "clean up #{file} for testing"
on agents, "rm -f #{file}"

step "run the manifest and verify MD5 was printed"
apply_manifest_on(agents, manifest) do
    fail_test "didn't find the content MD5 on output" unless
        stdout.include? "defined content as '{md5}098f6bcd4621d373cade4e832627b4f6'"
end

step "clean up #{file} after testing"
on agents, "rm -f #{file}"
