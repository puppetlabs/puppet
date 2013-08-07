test_name "Puppet applies resources without dependencies in file order"

manifest = %q{
notify { "first": }
notify { "second": }
notify { "third": }
notify { "fourth": }
notify { "fifth": }
notify { "sixth": }
notify { "seventh": }
notify { "eighth": }
}

apply_manifest_on(agents, manifest) do
  if stdout !~ /Notice: first.*Notice: second.*Notice: third.*Notice: fourth.*Notice: fifth.*Notice: sixth.*Notice: seventh.*Notice: eighth/m
    fail_test "Output did not include the notify resources in the correct order"
  end
end
