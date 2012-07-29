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

agents.each do |host|
  apply_manifest_on(host, manifest) do
    assert_match(/parent array element/, stdout, "#{host}: parent missing")
    assert_match(/child array element/, stdout, "#{host}: child missing")
  end
end
