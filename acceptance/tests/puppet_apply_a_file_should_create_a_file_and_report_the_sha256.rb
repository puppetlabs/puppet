test_name "puppet apply should create a file and report a SHA256 digest"

tag 'audit:medium',
    'audit:unit'

agents.each do |agent|
  file = agent.tmpfile('hello-world')
  manifest = "file{'#{file}': content => 'test'}"

  step "clean up #{file} for testing"
  on(agent, "rm -f #{file}")

  step "Run the manifest and verify SHA256 was printed"
  apply_manifest_on(agent, manifest) do
    assert_match(/defined content as '{sha256}9f86d081884c7d659a2feaa0c55ad015a3bf4f1b2b0b822cd15d6c15b0f00a08'/, stdout, "#{agent}: didn't find the content SHA256 on output")
  end

  step "clean up #{file} after testing"
  on(agent, "rm -f #{file}")
end
