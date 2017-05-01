#! /usr/bin/env ruby
require 'spec_helper'
require 'puppet/util/character_encoding'
require 'puppet_spec/character_encoding'

describe Puppet::Util::CharacterEncoding do
  describe "::convert_to_utf_8!" do
    context "when passed a string that is already UTF-8" do
      context "with valid encoding" do
        it "should not modify the string" do
          utf8_string = "\u06FF\u2603"
          Puppet::Util::CharacterEncoding.convert_to_utf_8!(utf8_string)
          expect(utf8_string).to eq("\u06FF\u2603")
        end
      end

      context "with invalid encoding" do
        let(:invalid_utf8_string) { "\xfd\xf1".force_encoding(Encoding::UTF_8) }

        it "should issue a debug message" do
          Puppet.expects(:debug).with(regexp_matches(/encoding is invalid/))
          Puppet::Util::CharacterEncoding.convert_to_utf_8!(invalid_utf8_string)
        end

        it "should not modify the string" do
          Puppet::Util::CharacterEncoding.convert_to_utf_8!(invalid_utf8_string)
          expect(invalid_utf8_string).to eq("\xfd\xf1".force_encoding(Encoding::UTF_8))
        end
      end
    end

    context "when passed a string not in UTF-8 encoding" do
      it "should be able to convert BINARY to UTF-8 by labeling as Encoding.default_external" do
        # そ - HIRAGANA LETTER SO
        # In Windows_31J: \x82 \xbb - 130 187
        # In Unicode: \u305d - \xe3 \x81 \x9d - 227 129 157

        # When received as BINARY are not transcodable, but by "guessing"
        # Encoding.default_external can transcode to UTF-8
        win_31j = [130, 187].pack('C*')

        PuppetSpec::CharacterEncoding.with_external_encoding(Encoding::Windows_31J) do
          Puppet::Util::CharacterEncoding.convert_to_utf_8!(win_31j)
        end

        expect(win_31j).to eq("\u305d")
        expect(win_31j.bytes.to_a).to eq([227, 129, 157])
      end

      context "that is BINARY encoded but invalid in Encoding.default_external" do
        let(:invalid_win_31j) { [255, 254, 253].pack('C*') } # these bytes are not valid windows_31j

        it "should leave the string umodified" do
          PuppetSpec::CharacterEncoding.with_external_encoding(Encoding::Windows_31J) do
            Puppet::Util::CharacterEncoding.convert_to_utf_8!(invalid_win_31j)
          end
          expect(invalid_win_31j.bytes.to_a).to eq([255, 254, 253])
          expect(invalid_win_31j.encoding).to eq(Encoding::BINARY)
        end

        it "should issue a debug message that the string was not transcodable" do
          Puppet.expects(:debug).with(regexp_matches(/cannot be transcoded/))
          PuppetSpec::CharacterEncoding.with_external_encoding(Encoding::Windows_31J) do
            Puppet::Util::CharacterEncoding.convert_to_utf_8!(invalid_win_31j)
          end
        end
      end

      it "should transcode the string to UTF-8 if it is transcodable" do
        # http://www.fileformat.info/info/unicode/char/3050/index.htm
        # ぐ - HIRAGANA LETTER GU
        # In Shift_JIS: \x82 \xae - 130 174
        # In Unicode: \u3050 - \xe3 \x81 \x90 - 227 129 144
        # if we were only ruby > 2.3.0, we could do String.new("\x82\xae", :encoding => Encoding::Shift_JIS)
        shift_jis = [130, 174].pack('C*').force_encoding(Encoding::Shift_JIS)

        Puppet::Util::CharacterEncoding.convert_to_utf_8!(shift_jis)
        expect(shift_jis).to eq("\u3050")
        # largely redundant but reinforces the point - this was transcoded:
        expect(shift_jis.bytes.to_a).to eq([227, 129, 144])
      end

      context "when not transcodable" do
        # An admittedly contrived case, but perhaps not so improbable
        # http://www.fileformat.info/info/unicode/char/5e0c/index.htm
        # 希 Han Character 'rare; hope, expect, strive for'
        # In EUC_KR: \xfd \xf1 - 253 241
        # In Unicode: \u5e0c - \xe5 \xb8 \x8c - 229 184 140

        # In this case, this EUC_KR character has been read in as ASCII and is
        # invalid in that encoding. This would raise an EncodingError
        # exception on transcode but we catch this issue a debug message -
        # leaving the original string unaltered.
        let(:euc_kr) { [253, 241].pack('C*').force_encoding(Encoding::ASCII) }

        it "should issue a debug message" do
          Puppet.expects(:debug).with(regexp_matches(/cannot be transcoded/))
          Puppet::Util::CharacterEncoding.convert_to_utf_8!(euc_kr)
        end

        it "should not modify the string" do
          Puppet::Util::CharacterEncoding.convert_to_utf_8!(euc_kr)
          expect(euc_kr).to eq([253, 241].pack('C*').force_encoding(Encoding::ASCII))
        end
      end
    end
  end

  describe "::override_encoding_to_utf_8!" do
    context "given a string with bytes that represent valid UTF-8" do
      it "should set the external encoding of the string to UTF-8" do
        # ☃ - unicode snowman
        # \u2603 - \xe2 \x98 \x83 - 226 152 131
        snowman = [226, 152, 131].pack('C*')
        Puppet::Util::CharacterEncoding.override_encoding_to_utf_8!(snowman)
        expect(snowman).to eq("\u2603")
        expect(snowman.encoding).to eq(Encoding::UTF_8)
      end
    end

    context "given a string with bytes that do not represent valid UTF-8" do
      # Ø - Latin capital letter O with stroke
      # In ISO-8859-1: \xd8 - 216
      # Invalid in UTF-8 without transcoding
      let(:oslash) { [216].pack('C*').force_encoding(Encoding::ISO_8859_1) }
      let(:foo) { 'foo' }
      it "should issue a debug message" do
        Puppet.expects(:debug).with(regexp_matches(/not valid UTF-8/))
        Puppet::Util::CharacterEncoding.override_encoding_to_utf_8!(oslash)
      end

      it "should not modify the string" do
        Puppet::Util::CharacterEncoding.override_encoding_to_utf_8!(oslash)
        expect(oslash).to eq([216].pack('C*').force_encoding(Encoding::ISO_8859_1))
      end
    end
  end

  describe "::scrub" do
    let(:utf_8_string_to_scrub) { "\xfdfoo".force_encoding(Encoding::UTF_8) } # invalid in UTF-8
    # The invalid-ness of this string comes from unpaired surrogates, ie:
    #  "any value in the range D80016 to DBFF16 not followed by a value in the
    #  range DC0016 to DFFF16, or any value in the range DC0016 to DFFF16 not
    #  preceded by a value in the range D80016 to DBFF16"
    # http://unicode.org/faq/utf_bom.html#utf16-7
    # "a\ud800b"
    # We expect the "b" to be replaced as that is what makes the string invalid
    let(:utf_16LE_string_to_scrub) { [97, 237, 160, 128, 98].pack('C*').force_encoding(Encoding::UTF_16LE) } # invalid in UTF-16
    let(:invalid_non_utf) { "foo\u2603".force_encoding(Encoding::EUC_KR) } # EUC_KR foosnowman!

    it "should defer to String#scrub if defined", :if => String.method_defined?(:scrub) do
      result = Puppet::Util::CharacterEncoding.scrub(utf_8_string_to_scrub)
      # The result should have the UTF-8 replacement character if we're using Ruby scrub
      expect(result).to eq("\uFFFDfoo".force_encoding(Encoding::UTF_8))
      expect(result.bytes.to_a).to eq([239, 191, 189, 102, 111, 111])
    end

    context "when String#scrub is not defined" do
      it "should still issue unicode replacement characters if the string is UTF-8" do
        utf_8_string_to_scrub.stubs(:respond_to?).with(:scrub).returns(false)
        result = Puppet::Util::CharacterEncoding.scrub(utf_8_string_to_scrub)
        expect(result).to eq("\uFFFDfoo".force_encoding(Encoding::UTF_8))
      end

      it "should still issue unicode replacement characters if the string is UTF-16LE" do
        utf_16LE_string_to_scrub.stubs(:respond_to?).with(:scrub).returns(false)
        result = Puppet::Util::CharacterEncoding.scrub(utf_16LE_string_to_scrub)
        # Bytes of replacement character on UTF_16LE are [253, 255]
        # We just check for bytes because something (ruby?) interprets this array of bytes as:
        # (97) (237 160) (128 253 255) rather than (97) (237 160 128) (253 255)
        expect(result).to eq([97, 237, 160, 128, 253, 255].pack('C*').force_encoding(Encoding::UTF_16LE))
      end

      it "should issue '?' characters if the string is not one of UTF_8 or UTF_16LE" do
        invalid_non_utf.stubs(:respond_to?).with(:scrub).returns(false)
        result = Puppet::Util::CharacterEncoding.scrub(invalid_non_utf)
        expect(result).to eq("foo???".force_encoding(Encoding::EUC_KR))
      end
    end
  end
end
