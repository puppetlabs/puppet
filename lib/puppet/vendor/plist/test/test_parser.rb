##############################################################
# Copyright 2006, Ben Bleything <ben@bleything.net> and      #
#                 Patrick May <patrick@hexane.org>           #
#                                                            #
# Distributed under the MIT license.                         #
##############################################################

require 'test/unit'

require 'plist'

class TestParser < Test::Unit::TestCase
  def test_Plist_parse_xml
    result = Plist::parse_xml("test/assets/AlbumData.xml")

    # dict
    assert_kind_of( Hash, result )
    assert_equal( ["List of Albums",
                   "Minor Version",
                   "Master Image List",
                   "Major Version",
                   "List of Keywords",
                   "Archive Path",
                   "List of Rolls",
                   "Application Version"],
                  result.keys )

    # array
    assert_kind_of( Array, result["List of Rolls"] )
    assert_equal( [ {"PhotoCount"=>1,
                     "KeyList"=>["7"],
                     "Parent"=>999000,
                     "Album Type"=>"Regular",
                     "AlbumName"=>"Roll 1",
                     "AlbumId"=>6}],
                  result["List of Rolls"] )

    # string
    assert_kind_of( String, result["Application Version"] )
    assert_equal( "5.0.4 (263)", result["Application Version"] )

    # integer
    assert_kind_of( Integer, result["Major Version"] )
    assert_equal( 2, result["Major Version"] )

    # true
    assert_kind_of( TrueClass, result["List of Albums"][0]["Master"] )
    assert( result["List of Albums"][0]["Master"] )

    # false
    assert_kind_of( FalseClass, result["List of Albums"][1]["SlideShowUseTitles"] )
    assert( ! result["List of Albums"][1]["SlideShowUseTitles"] )

  end

  # uncomment this test to work on speed optimization
  #def test_load_something_big
  #  plist = Plist::parse_xml( "~/Pictures/iPhoto Library/AlbumData.xml" )
  #end

  # date fields are credited to
  def test_date_fields
    result = Plist::parse_xml("test/assets/Cookies.plist")
    assert_kind_of( DateTime, result.first['Expires'] )
    assert_equal( "2007-10-25T12:36:35Z", result.first['Expires'].to_s )
  end

  # bug fix for empty <key>
  # reported by Matthias Peick <matthias@peick.de>
  # reported and fixed by Frederik Seiffert <ego@frederikseiffert.de>
  def test_empty_dict_key
    data = Plist::parse_xml("test/assets/test_empty_key.plist");
    assert_equal("2", data['key']['subkey'])
  end

  # bug fix for decoding entities
  #  reported by Matthias Peick <matthias@peick.de>
  def test_decode_entities
    data = Plist::parse_xml('<string>Fish &amp; Chips</string>')
    assert_equal('Fish & Chips', data)
  end

  def test_comment_handling_and_empty_plist
    assert_nothing_raised do
      assert_nil( Plist::parse_xml( File.read('test/assets/commented.plist') ) )
    end
  end
end

__END__
