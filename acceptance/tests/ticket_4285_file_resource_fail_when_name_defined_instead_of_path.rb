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

agents.each do |host|
  apply_manifest_on(host, manifest) do
    assert_no_match(/Cannot alias/, stdout, "#{host}: found the bug report output")
  end
end
