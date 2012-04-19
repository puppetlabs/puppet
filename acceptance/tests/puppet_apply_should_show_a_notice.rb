test_name "puppet apply should show a notice"

agents.each do |host|
  apply_manifest_on(host, "notice 'Hello World'") do
    assert_match(/.*: Hello World/, stderr, "#{host}: the notice didn't show")
  end
end
