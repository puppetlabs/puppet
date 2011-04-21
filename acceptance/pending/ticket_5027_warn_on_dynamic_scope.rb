test_name "#5027: Issue warnings when using dynamic scope"

step "Apply dynamic scoping manifest on agents"
apply_manifest_on agents, %q{
  $foo = 'foo_value'

  class a {
      $bar = 'bar_value'

      include b
  }

  class b inherits c {
      notify { $baz: } # should not generate a warning -- inherited from class c
      notify { $bar: } # should generate a warning -- uses dynamic scoping
      notify { $foo: } # should not generate a warning -- comes from top scope
  }

  class c {
      $baz = 'baz_value'
  }

  include a
}

step "Verify deprecation warning"
fail_test "Deprecation warning not issued" unless
  stdout.include? 'warning: Dynamic lookup of $bar will not be supported in future versions. Use a fully-qualified variable name or parameterized classes.'
