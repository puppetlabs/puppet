test_name "cycle detection and reporting"

tag 'audit:high',
    'audit:unit',  # This should be covered at the unit layer.
    'audit:delete'

step "check we report a simple cycle"
manifest = <<EOT
notify { "a1": require => Notify["a2"] }
notify { "a2": require => Notify["a1"] }
EOT
agents.each do |host|
  apply_manifest_on(host, manifest, :acceptable_exit_codes => [1]) do
    unless host['locale'] == 'ja'
      assert_match(/Found 1 dependency cycle/, stderr,
                   "found and reported the cycle correctly")
    end
  end
end

step "report multiple cycles in the same graph"
manifest = <<EOT
notify { "a1": require => Notify["a2"] }
notify { "a2": require => Notify["a1"] }

notify { "b1": require => Notify["b2"] }
notify { "b2": require => Notify["b1"] }
EOT

agents.each do |host|
  apply_manifest_on(host, manifest, :acceptable_exit_codes => [1]) do
    unless host['locale'] == 'ja'
      assert_match(/Found 2 dependency cycles/, stderr,
                   "found and reported the cycle correctly")
    end
  end
end
