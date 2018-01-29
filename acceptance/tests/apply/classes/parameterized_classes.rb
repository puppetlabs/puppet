test_name "parametrized classes"

tag 'audit:high',
    'audit:unit'   # This should be covered at the unit layer.

########################################################################
step "should allow param classes"
manifest = %q{
class x($y, $z) {
  notice("${y}-${z}")
}
class {x: y => '1', z => '2'}
}

apply_manifest_on(agents, manifest) do
    fail_test "inclusion after parameterization failed" unless stdout.include? "1-2"
end

########################################################################
# REVISIT: This was ported from the old set of tests, but I think that
# the desired behaviour has recently changed.  --daniel 2010-12-23
step "should allow param class post inclusion"
manifest = %q{
class x($y, $z) {
  notice("${y}-${z}")
}
class {x: y => '1', z => '2'}
include x
}

apply_manifest_on(agents, manifest) do
    fail_test "inclusion after parameterization failed" unless stdout.include? "1-2"
end

########################################################################
step "should allow param classes defaults"
manifest = %q{
class x($y, $z='2') {
  notice("${y}-${z}")
}
class {x: y => '1'}
}

apply_manifest_on(agents, manifest) do
    fail_test "the default didn't apply as expected" unless stdout.include? "1-2"
end

########################################################################
step "should allow param class defaults to be overridden"
manifest = %q{
class x($y, $z='2') {
  notice("${y}-${z}")
}
class {x: y => '1', z => '3'}
}

apply_manifest_on(agents, manifest) do
    fail_test "the override didn't happen as we expected" unless stdout.include? "1-3"
end
