test_name "First resource depends on last resource with one in between"

manifest = %q{
notify { "first": require => Notify["third"]}
notify { "second": }
notify { "third": }
}

apply_manifest_on(agents, manifest) do
  if stdout !~ /Notice: second.*Notice: third.*Notice: first/m
    fail_test "Did not get expected order: second, third, first"
  end
end
