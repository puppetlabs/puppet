test_name "puppet module list (with no installed modules)"


step "List the installed modules"
modulesdir = master.tmpdir('puppet_module')
on master, puppet("module list --modulepath #{modulesdir}") do
  assert_match(/no modules installed/, stdout,
        "Declaration of 'no modules installed' not found")
end
