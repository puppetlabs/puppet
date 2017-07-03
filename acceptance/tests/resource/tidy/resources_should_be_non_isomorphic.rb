# This test is to verify multi tidy resources with same path but
# different matches should not cause error as found in the bug PUP-6508
test_name "PUP-6655 - C98145 tidy resources should be non-isomorphic" do
  tag 'audit:medium',
      'audit:integration'

  agents. each do |agent|
    dir = agent.tmpdir('tidy-test-dir')
    on(agent, "mkdir -p #{dir}")

    files = %w{file1.txt file2.doc}
    on(agent, "touch #{dir}/{#{files.join(',')}}")

    manifest = <<-MANIFEST
tidy {'tidy-resource1':
  path  => "#{dir}",
  matches => "*.txt",
  recurse => true,
}
tidy {'tidy-resource2':
  path  => "#{dir}",
  matches => "*.doc",
  recurse => true,
}
MANIFEST

    step "Ensure the newly created files are present:" do
      present = files.map {|file| "-f #{File.join(dir, file)}"}.join(' -a ')
      on(agent, "[ #{present} ]")
    end

    step "Create multiple tidy resources with same path" do
      apply_manifest_on(agent, manifest) do |result|
        assert_no_match(/Error:/, result.stderr, "Unexpected error was detected")
      end
    end

    step "Verify that the files are actually removed successfully:" do
      present = files.map {|file| "-f #{File.join(dir, file)}"}.join(' -o ')
      on(agent, "[ #{present} ]", :acceptable_exit_codes => [1])
    end

    teardown do
      on(agent, puppet("apply -e \"file{'#{dir}': ensure => absent, force => true}\""))
    end
  end
end
