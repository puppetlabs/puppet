test_name "Can enumerate environments via an HTTP endpoint"

with_puppet_running_on(master, {}) do
  agents.each do |agent|
    on agent, "curl -ksv https://#{master}:8140/v2/environments", :acceptable_exit_codes => [0,7] do
      assert_match(/< HTTP\/1\.\d 403/, stderr)
    end
  end
end
