test_name "Bug #4285: ArgumentError: Cannot alias File[mytitle] to [nil]"

manifest = %q{
  file { "file1":
      name => '/tmp/file1',
      source => "/tmp/",
  }

  file { "file2":
      name => '/tmp/file2',
      source => "/tmp/",
  }
}

apply_manifest_on(agents, manifest) do
    fail_test "found the bug report output" if stdout =~ /Cannot alias/
end
