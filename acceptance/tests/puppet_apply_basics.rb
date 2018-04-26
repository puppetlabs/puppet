# Ported from a collection of small spec tests in acceptance.
#
# Unified into a single file because they are literally one-line tests!

test_name "Trivial puppet tests"

tag 'audit:medium',
    'audit:unit'

step "check that puppet apply displays notices"
agents.each do |host|
  apply_manifest_on(host, "notice 'Hello World'") do
    assert_match(/Hello World/, stdout, "#{host}: missing notice!")
  end
end
