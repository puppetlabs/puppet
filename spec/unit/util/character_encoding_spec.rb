#! /usr/bin/env ruby
require 'spec_helper'
require 'puppet/util/character_encoding'

describe Puppet::Util::CharacterEncoding do
  describe "::convert_to_utf_8!" do
    context "when passed a string that is already UTF-8" do
      context "with valid encoding" do
        it "should return the string unaltered" do
          utf8_string = "\u06FF\u2603"
          expect(Puppet::Util::CharacterEncoding.convert_to_utf_8!(utf8_string)).to eq(utf8_string)
        end
      end

      context "with invalid encoding" do
        let(:invalid_utf8_string) { "\xfd\xf1".force_encoding(Encoding::UTF_8) }

        it "should issue a debug message" do
          Puppet.expects(:debug).with(regexp_matches(/not valid UTF-8/))
          Puppet::Util::CharacterEncoding.convert_to_utf_8!(invalid_utf8_string)
        end

        it "should return nil" do
          expect(Puppet::Util::CharacterEncoding.convert_to_utf_8!(invalid_utf8_string)).to be_nil
        end
      end
    end

    context "when passed a string not in UTF-8 encoding" do
      context "the bytes of which represent valid UTF-8" do
        # I think this effectively what the ruby Etc module is doing when it
        # returns strings read in from /etc/passwd and /etc/group
        let(:iso_8859_1_string) { [225, 154, 160].pack('C*').force_encoding(Encoding::ISO_8859_1) }
        let(:result) { Puppet::Util::CharacterEncoding.convert_to_utf_8!(iso_8859_1_string) }

        it "should set external encoding to UTF-8" do
          expect(result.encoding).to eq(Encoding::UTF_8)
        end

        it "should not modify the bytes (transcode) the string" do
          expect(result.bytes.to_a).to eq([225, 154, 160])
        end
      end

      context "the bytes of which do not represent valid UTF-8" do
        it "should transcode the string to UTF-8 if it is transcodable" do
          # http://www.fileformat.info/info/unicode/char/3050/index.htm
          # ぐ - HIRAGANA LETTER GU
          # In Shift_JIS: \x82 \xae - 130 174
          # In Unicode: \u3050 - \xe3 \x81 \x90 - 227 129 144
          # if we were only ruby > 2.3.0, we could do String.new("\x82\xae", :encoding => Encoding::Shift_JIS)
          as_shift_jis = [130, 174].pack('C*').force_encoding(Encoding::Shift_JIS)
          as_utf8 = "\u3050"

          # this is not valid UTF-8
          expect(as_shift_jis.dup.force_encoding(Encoding::UTF_8).valid_encoding?).to be_falsey

          result = Puppet::Util::CharacterEncoding.convert_to_utf_8!(as_shift_jis)
          expect(result).to eq(as_utf8)
          # largely redundant but reinforces the point - this was transcoded:
          expect(result.bytes.to_a).to eq([227, 129, 144])
        end

        context "if it is not transcodable" do
          let(:as_ascii) { [254, 241].pack('C*').force_encoding(Encoding::ASCII) }
          it "should issue a debug message and return nil if not transcodable" do
            # An admittedly contrived case, but perhaps not so improbable
            # http://www.fileformat.info/info/unicode/char/5e0c/index.htm
            # 希 Han Character 'rare; hope, expect, strive for'
            # In EUC_KR: \xfd \xf1 - 253 241
            # In Unicode: \u5e0c - \xe5 \xb8 \x8c - 229 184 140

            # If the original system value is in EUC_KR, and puppet (ruby) is run
            # in ISO_8859_1, this value will be read in as ASCII, with invalid
            # escape sequences in that encoding. It is also not valid unicode
            # as-is. This scenario is one we can't recover from, so fail.
            Puppet.expects(:debug).with(regexp_matches(/not valid UTF-8/))
            Puppet::Util::CharacterEncoding.convert_to_utf_8!(as_ascii)
          end

          it "should return nil" do
            expect(Puppet::Util::CharacterEncoding.convert_to_utf_8!(as_ascii)).to be_nil
          end
        end
      end
    end
  end
end
