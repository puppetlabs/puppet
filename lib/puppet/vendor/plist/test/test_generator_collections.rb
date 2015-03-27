##############################################################
# Copyright 2006, Ben Bleything <ben@bleything.net> and      #
#                 Patrick May <patrick@hexane.org>           #
#                                                            #
# Distributed under the MIT license.                         #
##############################################################

require 'test/unit'
require 'plist'

class TestGeneratorCollections < Test::Unit::TestCase
  def test_array
    expected = <<END
<array>
	<integer>1</integer>
	<integer>2</integer>
	<integer>3</integer>
</array>
END

    assert_equal expected, [1,2,3].to_plist(false)
  end

  def test_empty_array
    expected = <<END
<array/>
END

    assert_equal expected, [].to_plist(false)
  end

  def test_hash
    expected = <<END
<dict>
	<key>abc</key>
	<integer>123</integer>
	<key>foo</key>
	<string>bar</string>
</dict>
END
    # thanks to recent changes in the generator code, hash keys are sorted before emission,
    # so multi-element hash tests should be reliable.  We're testing that here too.
    assert_equal expected, {:foo => :bar, :abc => 123}.to_plist(false)
  end

  def test_empty_hash
    expected = <<END
<dict/>
END

    assert_equal expected, {}.to_plist(false)
  end

  def test_hash_with_array_element
    expected = <<END
<dict>
	<key>ary</key>
	<array>
		<integer>1</integer>
		<string>b</string>
		<string>3</string>
	</array>
</dict>
END
    assert_equal expected, {:ary => [1,:b,'3']}.to_plist(false)
  end

  def test_array_with_hash_element
    expected = <<END
<array>
	<dict>
		<key>foo</key>
		<string>bar</string>
	</dict>
	<string>b</string>
	<integer>3</integer>
</array>
END

    assert_equal expected, [{:foo => 'bar'}, :b, 3].to_plist(false)
  end
end
