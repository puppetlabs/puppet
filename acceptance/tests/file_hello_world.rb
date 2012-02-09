# Verify that a trivial manifest can be run to completion.
test_name "The challenging 'Hello, World' manifest"

agents.each do |agent|
  filename = agent.tmpfile('hello-world.txt')
  content  = "Hello, World"
  manifest = "file { '#{filename}': content => '#{content}' }"

  step "ensure we are clean before testing..."
  on(agent, "rm -f #{filename}")

  step "run the manifest itself"
  apply_manifest_on(agent, manifest) do
    fail_test "the expected notice of action was missing" unless
      stdout.index "File[#{filename}]/ensure: defined content as"
  end

  step "verify the content of the generated files."
  on agent, "grep '#{content}' #{filename}"

  step "clean up after our test run."
  on(agent, "rm -f #{filename}")
end
