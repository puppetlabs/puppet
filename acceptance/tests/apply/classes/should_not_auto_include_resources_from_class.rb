test_name "resources declared in classes are not applied without include"
manifest = %q{ class x { notify { 'test': message => 'never invoked' } } }
apply_manifest_on(agents, manifest) do
    fail_test "found the notify despite not including it" if
        stdout.include? "never invoked"
end
