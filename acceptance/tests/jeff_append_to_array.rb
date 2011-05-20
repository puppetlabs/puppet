# Ported from the acceptance test suite.
test_name "Jeff: Append to Array"

manifest = %q{
    class parent {
      $arr1 = [ "parent array element" ]
    }
    class parent::child inherits parent {
      $arr1 += [ "child array element" ]
      notify { $arr1: }
    }
    include parent::child
}

apply_manifest_on(agents, manifest) do
  stdout =~ /notice: parent array element/ or fail_test("parent missing")
  stdout =~ /notice: child array element/  or fail_test("child missing")
end

