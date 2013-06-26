test_name "puppet apply should create a file and report an MD5"

agents.each do |agent|
  file = agent.tmpfile('hello-world')
  manifest = "file{'#{file}': content => 'test'}"

  step "clean up #{file} for testing"
  on(agent, "rm -f #{file}")

  step "Run the manifest and verify MD5 was printed"
  apply_manifest_on(agent, manifest) do
    assert_match(/defined content as '{md5}098f6bcd4621d373cade4e832627b4f6'/, stdout, "#{agent}: didn't find the content MD5 on output")
  end

  step "clean up #{file} after testing"
  on(agent, "rm -f #{file}")
end
