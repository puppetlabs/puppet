test_name "puppet apply should create a file and report an MD5"

file = "/tmp/hello.world.#{Time.new.to_i}.txt"
manifest = "file{'#{file}': content => 'test'}"

step "clean up #{file} for testing"
on agents, "rm -f #{file}"

step "Run the manifest and verify MD5 was printed"
agents.each do |host|
  apply_manifest_on(host, manifest) do
    assert_match(/defined content as '{md5}098f6bcd4621d373cade4e832627b4f6'/, stdout, "#{host}: didn't find the content MD5 on output")
  end
end

step "clean up #{file} after testing"
on agents, "rm -f #{file}"
