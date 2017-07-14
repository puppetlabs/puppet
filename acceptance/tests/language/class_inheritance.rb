test_name 'C14943: Class inheritance works correctly' do

tag 'audit:low',
    'audit:unit'   # This is testing core ruby functionality

  agents.each do |agent|
    test_manifest = <<MANIFEST
      class bar { notice("This is class bar") }
      class foo::bar { notice("This is class foo::bar") }
      class foo inherits bar { notice("This is class foo") }

      include foo
MANIFEST

    results = apply_manifest_on(agent, test_manifest, :accept_any_exit_code => true)
    assert_match(/Scope\(Class\[Bar\]\): This is class bar/, results.stdout, 'did not find class bar')
    assert_match(/Scope\(Class\[Foo\]\): This is class foo/, results.stdout, 'did not find class foo')
    refute_match(/This is class foo::bar/, results.stdout, 'should not have found class foo::bar')
  end

end
