# Verify that a trivial manifest can be run to completion.

filename = "/tmp/hello-world.txt"
content  = "Hello, World"
manifest = "file { '#{filename}': content => '#{content}' }"

test_name "The challenging 'Hello, World' manifest"

step "ensure we are clean before testing..."
on agents, "rm -f #{filename}"

step "run the manifest itself"
apply_manifest_on(agents, manifest) do
  fail_test "the expected notice of action was missing" unless
    stdout.index 'File[/tmp/hello-world.txt]/ensure: defined content as'
end

step "verify the content of the generated files."
on agents, "grep '#{content}' #{filename}"

step "clean up after our test run."
on agents, "rm -f #{filename}"
