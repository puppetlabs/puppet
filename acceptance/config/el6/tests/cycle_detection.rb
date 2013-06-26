test_name "cycle detection and reporting"

step "check we report a simple cycle"
manifest = <<EOT
notify { "a1": require => Notify["a2"] }
notify { "a2": require => Notify["a1"] }
EOT

apply_manifest_on(agents, manifest) do
  assert_match(/Found 1 dependency cycle/, stderr,
               "found and reported the cycle correctly")
end

step "report multiple cycles in the same graph"
manifest = <<EOT
notify { "a1": require => Notify["a2"] }
notify { "a2": require => Notify["a1"] }

notify { "b1": require => Notify["b2"] }
notify { "b2": require => Notify["b1"] }
EOT

apply_manifest_on(agents, manifest) do
  assert_match(/Found 2 dependency cycles/, stderr,
               "found and reported the cycle correctly")
end
