require 'spec_helper'
require 'puppet/pops'
require 'puppet_spec/compiler'

module Puppet::Pops
module Types
describe 'Binary Type' do
  include PuppetSpec::Compiler

  context 'as a type' do
    it 'can be created with the type factory' do
      t = TypeFactory.binary()
      expect(t).to be_a(PBinaryType)
      expect(t).to eql(PBinaryType::DEFAULT)
    end
  end

  context 'a Binary instance' do
    it 'can be created from a raw String using %r, raw string mode' do
      str = [0xF1].pack("C*")
      code = <<-CODE
        $x = Binary($testing, '%r')
        notice(assert_type(Binary, $x))
      CODE
      expect(eval_and_collect_notices(code, Puppet::Node.new('foonode'), { 'testing' => str })).to eql(['8Q=='])
    end

    it 'can be created from a String using %s, string mode' do
      # the text 'binar' needs padding with '='
      code = <<-CODE
        $x = Binary('binary', '%s')
        notice(assert_type(Binary, $x))
      CODE
      expect(eval_and_collect_notices(code)).to eql(['YmluYXJ5'])
    end

    it 'format %s errors if encoding is bad in given string when using format %s and a broken UTF-8 string' do
      str = [0xF1].pack("C*")
      str.force_encoding('UTF-8')
      code = <<-CODE
        $x = Binary($testing, '%s')
        notice(assert_type(Binary, $x))
      CODE
      expect {
        eval_and_collect_notices(code, Puppet::Node.new('foonode'), { 'testing' => str })
      }.to raise_error(/.*The given string in encoding 'UTF-8' is invalid\. Cannot create a Binary UTF-8 representation.*/)
    end

    it 'format %s errors if encoding is correct but string cannot be transcoded to UTF-8' do
      str = [0xF1].pack("C*")
      code = <<-CODE
        $x = Binary($testing, '%s')
        notice(assert_type(Binary, $x))
      CODE
      expect {
        eval_and_collect_notices(code, Puppet::Node.new('foonode'), { 'testing' => str })
      }.to raise_error(/.*"\\xF1" from ASCII-8BIT to UTF-8.*/)
    end

    it 'can be created from a strict Base64 encoded String using default format' do
      code = <<-CODE
        $x = Binary('YmluYXI=')
        notice(assert_type(Binary, $x))
      CODE
      expect(eval_and_collect_notices(code)).to eql(['YmluYXI='])
    end

    it 'will error creation in strict mode if padding is missing when using default format' do
      # the text 'binar' needs padding with '=' (missing here to trigger error
      code = <<-CODE
        $x = Binary('YmluYXI')
        notice(assert_type(Binary, $x))
      CODE
      expect{ eval_and_collect_notices(code) }.to raise_error(/invalid base64/)
    end

    it 'can be created from a Base64 encoded String using %B, strict mode' do
      # the text 'binar' needs padding with '='
      code = <<-CODE
        $x = Binary('YmluYXI=', '%B')
        notice(assert_type(Binary, $x))
      CODE
      expect(eval_and_collect_notices(code)).to eql(['YmluYXI='])
    end

    it 'will error creation in strict mode if padding is missing' do
      # the text 'binar' needs padding with '=' (missing here to trigger error
      code = <<-CODE
        $x = Binary('YmluYXI', '%B')
        notice(assert_type(Binary, $x))
      CODE
      expect{ eval_and_collect_notices(code) }.to raise_error(/invalid base64/)
    end

    it 'will not error creation in base mode if padding is missing' do
      # the text 'binar' needs padding with '=' (missing here to trigger possible error)
      code = <<-CODE
        $x = Binary('YmluYXI', '%b')
        notice(assert_type(Binary, $x))
      CODE
      expect(eval_and_collect_notices(code)).to eql(['YmluYXI='])
    end

    it 'will not error creation in base mode if padding is not required' do
      # the text 'binary' does not need padding with '='
      code = <<-CODE
        $x = Binary('YmluYXJ5', '%b')
        notice(assert_type(Binary, $x))
      CODE
      expect(eval_and_collect_notices(code)).to eql(['YmluYXJ5'])
    end

    it 'can be compared to another instance for equality' do
      code = <<-CODE
        $x = Binary('YmluYXJ5')
        $y = Binary('YmluYXJ5')
        notice($x == $y)
        notice($x != $y)
      CODE
      expect(eval_and_collect_notices(code)).to eql(['true', 'false'])
    end

    it 'can be created from an array of byte values' do
      # the text 'binar' needs padding with '='
      code = <<-CODE
        $x = Binary([251, 239, 255])
        notice(assert_type(Binary, $x))
      CODE
      expect(eval_and_collect_notices(code)).to eql(['++//'])
    end

    it "can be created from an hash with value and format" do
      # the text 'binar' needs padding with '='
      code = <<-CODE
        $x = Binary({value => '--__', format => '%u'})
        notice(assert_type(Binary, $x))
      CODE
      expect(eval_and_collect_notices(code)).to eql(['++//'])
    end

    it "can be created from an hash with value and default format" do
      code = <<-CODE
        $x = Binary({value => 'YmluYXI='})
        notice(assert_type(Binary, $x))
      CODE
      expect(eval_and_collect_notices(code)).to eql(['YmluYXI='])
    end

    it 'can be created from a hash with value being an array' do
      # the text 'binar' needs padding with '='
      code = <<-CODE
        $x = Binary({value => [251, 239, 255]})
        notice(assert_type(Binary, $x))
      CODE
      expect(eval_and_collect_notices(code)).to eql(['++//'])
    end

    it "can be created from an Base64 using URL safe encoding by specifying '%u' format'" do
      # the text 'binar' needs padding with '='
      code = <<-CODE
        $x = Binary('--__', '%u')
        notice(assert_type(Binary, $x))
      CODE
      expect(eval_and_collect_notices(code)).to eql(['++//'])
    end

    it "when created with URL safe encoding chars in '%b' format, these are skipped" do
      code = <<-CODE
        $x = Binary('--__YmluYXJ5', '%b')
        notice(assert_type(Binary, $x))
      CODE
      expect(eval_and_collect_notices(code)).to eql(['YmluYXJ5'])
    end

    it "will error in strict format if string contains URL safe encoded chars" do
      code = <<-CODE
        $x = Binary('--__YmluYXJ5', '%B')
        notice(assert_type(Binary, $x))
      CODE
      expect { eval_and_collect_notices(code) }.to raise_error(/invalid base64/)
    end

    [   '<',
        '<=',
        '>',
        '>='
    ].each do |op|
      it "cannot be compared to another instance for magnitude using #{op}" do
        code = <<-"CODE"
          $x = Binary('YmluYXJ5')
          $y = Binary('YmluYXJ5')
          $x #{op} $y
        CODE
        expect { eval_and_collect_notices(code)}.to raise_error(/Comparison of: Binary #{op} Binary, is not possible/)
      end
    end

    it 'can be matched against a Binary in case expression' do
      code = <<-CODE
        case Binary('YmluYXJ5') {
          Binary('YWxpZW4='): {
            notice('nope')
          }
          Binary('YmluYXJ5'): {
            notice('yay')
          }
          default: {
            notice('nope')
          }
        }
      CODE
      expect(eval_and_collect_notices(code)).to eql(['yay'])
    end

    it "can be matched against a Binary subsequence using 'in' expression" do
      # finding 'one' in 'one two three'
      code = <<-CODE
        notice(Binary("b25l") in Binary("b25lIHR3byB0aHJlZQ=="))
        notice(Binary("c25l") in Binary("b25lIHR3byB0aHJlZQ=="))
      CODE
      expect(eval_and_collect_notices(code)).to eql(['true', 'false'])
    end

    it "can be matched against a byte value using 'in' expression" do
      # finding 'e' (ascii 101) in 'one two three'
      code = <<-CODE
        notice(101 in Binary("b25lIHR3byB0aHJlZQ=="))
        notice(101.0 in Binary("b25lIHR3byB0aHJlZQ=="))
        notice(102 in Binary("b25lIHR3byB0aHJlZQ=="))
      CODE
      expect(eval_and_collect_notices(code)).to eql(['true', 'true', 'false'])
    end

    it "has a length method in ruby returning the length measured in bytes" do
      # \u{1f452} is "woman's hat emoji - 4 bytes in UTF-8"
      a_binary = PBinaryType::Binary.new("\u{1f452}")
      expect(a_binary.length).to be(4)
    end
  end

end
end
end
