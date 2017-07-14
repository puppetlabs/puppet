test_name "Bug #4285: ArgumentError: Cannot alias File[mytitle] to [nil]"

tag 'audit:low',     # Wierd File type name parameter handling
    'audit:refactor', # Use block style `test_name`
    'audit:unit'

agents.each do |host|
  dir = host.tmpdir('4285-aliasing')

manifest = %Q{
  file { "file1":
      name => '#{dir}/file1',
      source => "#{dir}/",
  }

  file { "file2":
      name => '#{dir}/file2',
      source => "#{dir}/",
  }
}

  apply_manifest_on(host, manifest) do
    assert_no_match(/Cannot alias/, stdout, "#{host}: found the bug report output")
  end
end
