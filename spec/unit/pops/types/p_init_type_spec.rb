require 'spec_helper'
require 'puppet/pops'
require 'puppet_spec/compiler'

module Puppet::Pops
module Types
describe 'The Init Type' do
  include PuppetSpec::Compiler
  include_context 'types_setup'

  context 'when used in Puppet expressions' do
    it 'an unparameterized type can be used' do
      code = <<-CODE
      notice(type(Init))
      CODE
      expect(eval_and_collect_notices(code)).to eql(['Type[Init]'])
    end

    it 'a parameterized type can be used' do
      code = <<-CODE
      notice(type(Init[Integer]))
      CODE
      expect(eval_and_collect_notices(code)).to eql(['Type[Init[Integer]]'])
    end

    it 'a parameterized type can have additional arguments' do
      code = <<-CODE
      notice(type(Init[Integer, 16]))
      CODE
      expect(eval_and_collect_notices(code)).to eql(['Type[Init[Integer, 16]]'])
    end

    (all_types - abstract_types - internal_types).map { |tc| tc::DEFAULT.name }.each do |type_name|
      it "can be created on a #{type_name}" do
        code = <<-CODE
        notice(type(Init[#{type_name}]))
        CODE
        expect(eval_and_collect_notices(code)).to eql(["Type[Init[#{type_name}]]"])
      end
    end

    (abstract_types - internal_types).map { |tc| tc::DEFAULT.name }.each do |type_name|
      it "cannot be created on a #{type_name}" do
        code = <<-CODE
        type(Init[#{type_name}]('x'))
        CODE
        expect { eval_and_collect_notices(code) }.to raise_error(/Creation of new instance of type '#{type_name}' is not supported/)
      end
    end

    it 'an Init[Integer, 16] can create an instance from a String' do
      code = <<-CODE
      notice(Init[Integer, 16]('100'))
      CODE
      expect(eval_and_collect_notices(code)).to eql(['256'])
    end

    it "an Init[String,'%x'] can create an instance from an Integer" do
      code = <<-CODE
      notice(Init[String,'%x'](128))
      CODE
      expect(eval_and_collect_notices(code)).to eql(['80'])
    end

    it "an Init[String,23] raises an error because no available dispatcher exists" do
      code = <<-CODE
      notice(Init[String,23](128))
      CODE
      expect { eval_and_collect_notices(code) }.to raise_error(
        /The type 'Init\[String, 23\]' does not represent a valid set of parameters for String\.new\(\)/)
    end

    it 'an Init[String] can create an instance from an Integer' do
      code = <<-CODE
      notice(Init[String](128))
      CODE
      expect(eval_and_collect_notices(code)).to eql(['128'])
    end

    it 'an Init[String] can create an instance from an array with an Integer' do
      code = <<-CODE
      notice(Init[String]([128]))
      CODE
      expect(eval_and_collect_notices(code)).to eql(['128'])
    end

    it 'an Init[String] can create an instance from an array with an Integer and a format' do
      code = <<-CODE
      notice(Init[String]([128, '%x']))
      CODE
      expect(eval_and_collect_notices(code)).to eql(['80'])
    end

    it 'an Init[String] can create an instance from an array with an array' do
      code = <<-CODE
      notice(Init[String]([[128, '%x']]))
      CODE
      expect(eval_and_collect_notices(code)).to eql(["[128, '%x']"])
    end

    it 'an Init[Binary] can create an instance from a string' do
      code = <<-CODE
      notice(Init[Binary]('b25lIHR3byB0aHJlZQ=='))
      CODE
      expect(eval_and_collect_notices(code)).to eql(['b25lIHR3byB0aHJlZQ=='])
    end

    it 'an Init[String] can not create an instance from an Integer and a format unless given as an array argument' do
      code = <<-CODE
      notice(Init[String](128, '%x'))
      CODE
      expect { eval_and_collect_notices(code) }.to raise_error(/'new_Init' expects 1 argument, got 2/)
    end

    it 'the array [128] is an instance of Init[String]' do
      code = <<-CODE
      notice(assert_type(Init[String], [128]))
      CODE
      expect(eval_and_collect_notices(code)).to eql(['[128]'])
    end

    it 'the value 128 is an instance of Init[String]' do
      code = <<-CODE
      notice(assert_type(Init[String], 128))
      CODE
      expect(eval_and_collect_notices(code)).to eql(['128'])
    end

    it "the array [128] is an instance of Init[String]" do
      code = <<-CODE
      notice(assert_type(Init[String], [128]))
      CODE
      expect(eval_and_collect_notices(code)).to eql(['[128]'])
    end

    it "the array [128, '%x'] is an instance of Init[String]" do
      code = <<-CODE
      notice(assert_type(Init[String], [128, '%x']))
      CODE
      expect(eval_and_collect_notices(code)).to eql(['[128, %x]'])
    end

    it "the array [[128, '%x']] is an instance of Init[String]" do
      code = <<-CODE
      notice(assert_type(Init[String], [[128, '%x']]))
      CODE
      expect(eval_and_collect_notices(code)).to eql(['[[128, %x]]'])
    end

    it 'RichData is assignable to Init' do
      code = <<-CODE
      notice(Init > RichData)
      CODE
      expect(eval_and_collect_notices(code)).to eql(['true'])
    end

    it 'Runtime is not assignable to Init' do
      code = <<-CODE
      notice(Init > Runtime['ruby', 'Time'])
      CODE
      expect(eval_and_collect_notices(code)).to eql(['false'])
    end

    it 'Init is not assignable to RichData' do
      code = <<-CODE
      notice(Init < RichData)
      CODE
      expect(eval_and_collect_notices(code)).to eql(['false'])
    end

    it 'Init[T1] is assignable to Init[T2] when T1 is assignable to T2' do
      code = <<-CODE
      notice(Init[Integer] < Init[Numeric])
      notice(Init[Tuple[Integer]] < Init[Array[Integer]])
      CODE
      expect(eval_and_collect_notices(code)).to eql(['true', 'true'])
    end

    it 'Init[T1] is not assignable to Init[T2] unless T1 is assignable to T2' do
      code = <<-CODE
      notice(Init[Integer] > Init[Numeric])
      notice(Init[Tuple[Integer]] > Init[Array[Integer]])
      CODE
      expect(eval_and_collect_notices(code)).to eql(['false', 'false'])
    end

    it 'T is assignable to Init[T]' do
      code = <<-CODE
      notice(Integer < Init[Integer])
      CODE
      expect(eval_and_collect_notices(code)).to eql(['true'])
    end

    it 'T1 is assignable to Init[T2] if T2 can be created from instance of T1' do
      code = <<-CODE
      notice(Integer < Init[String])
      CODE
      expect(eval_and_collect_notices(code)).to eql(['true'])
    end

    it 'a RichData value is an instance of Init' do
      code = <<-CODE
      notice(
        String(assert_type(Init, { 'a' => [ 1, 2, Sensitive(3) ], 2 => Timestamp('2014-12-01T13:15:00') }),
          { Any => { format => '%s', string_formats => { Any => '%s' }}}))
      CODE
      expect(eval_and_collect_notices(code)).to eql(['{a => [1, 2, Sensitive [value redacted]], 2 => 2014-12-01T13:15:00.000000000 UTC}'])
    end

    it 'an Init[Sensitive[String]] can create an instance from a String' do
      code = <<-CODE
      notice(Init[Sensitive[String]]('256'))
      CODE
      expect(eval_and_collect_notices(code)).to eql(['Sensitive [value redacted]'])
    end

    it 'an Init[Type] can create an instance from a String' do
      code = <<-CODE
      notice(Init[Type]('Integer[2,3]'))
      CODE
      expect(eval_and_collect_notices(code)).to eql(['Integer[2, 3]'])
    end

    it 'an Init[Type[Numeric]] can not create an unassignable type from a String' do
      code = <<-CODE
      notice(Init[Type[Numeric]]('String'))
      CODE
      expect { eval_and_collect_notices(code) }.to raise_error(
        /Converted value from Type\[Numeric\]\.new\(\) has wrong type, expects a Type\[Numeric\] value, got Type\[String\]/)
    end

    it 'an Init with a custom object type can create an instance from a Hash' do
      code = <<-CODE
      type MyType = Object[{
        attributes => {
          granularity => String,
          price => String,
          category => Integer
        }
      }]
      notice(Init[MyType]({ granularity => 'fine', price => '$10', category => 23 }))
      CODE
      expect(eval_and_collect_notices(code)).to eql(["MyType({'granularity' => 'fine', 'price' => '$10', 'category' => 23})"])
    end

    it 'an Init with a custom object type and additional parameters can create an instance from a value' do
      code = <<-CODE
      type MyType = Object[{
        attributes => {
          granularity => String,
          price => String,
          category => Integer
        }
      }]
      notice(Init[MyType,'$5',20]('coarse'))
      CODE
      expect(eval_and_collect_notices(code)).to eql(["MyType({'granularity' => 'coarse', 'price' => '$5', 'category' => 20})"])
    end

    it 'an Init with a custom object with one Array parameter, can be created from an Array' do
      code = <<-CODE
      type MyType = Object[{
        attributes => { array => Array[String] }
      }]
      notice(Init[MyType](['a']))
      CODE
      expect(eval_and_collect_notices(code)).to eql(["MyType({'array' => ['a']})"])
    end

    it 'an Init type can be used recursively' do
      # Even if it doesn't make sense, it should not crash
      code = <<-CODE
        type One = Object[{
          attributes => {
            init_one => Variant[Init[One],String]
          }
        }]
        notice(Init[One]('w'))
      CODE
      expect(eval_and_collect_notices(code)).to eql(["One({'init_one' => 'w'})"])
    end

    context 'computes if x is an instance such that' do
      %w(true false True False TRUE FALSE tRuE FaLsE Yes No yes no YES NO YeS nO y n Y N).each do |str|
        it "string '#{str}' is an instance of Init[Boolean]" do
          expect(eval_and_collect_notices("notice('#{str}' =~ Init[Boolean])")).to eql(['true'])
        end
      end

      it 'arbitrary string is not an instance of Init[Boolean]' do
        expect(eval_and_collect_notices("notice('blue' =~ Init[Boolean])")).to eql(['false'])
      end

      it 'empty string is not an instance of Init[Boolean]' do
        expect(eval_and_collect_notices("notice('' =~ Init[Boolean])")).to eql(['false'])
      end

      it 'undef string is not an instance of Init[Boolean]' do
        expect(eval_and_collect_notices("notice(undef =~ Init[Boolean])")).to eql(['false'])
      end

      %w(0 1 0634 0x3b -0xba 0b1001 +0b1111 23.14 -2.3 2e-21 1.23e18  -0.23e18).each do |str|
        it "string '#{str}' is an instance of Init[Numeric]" do
          expect(eval_and_collect_notices("notice('#{str}' =~ Init[Numeric])")).to eql(['true'])
        end
      end

      it 'non numeric string is not an instance of Init[Numeric]' do
        expect(eval_and_collect_notices("notice('blue' =~ Init[Numeric])")).to eql(['false'])
      end

      it 'empty string is not an instance of Init[Numeric]' do
        expect(eval_and_collect_notices("notice('' =~ Init[Numeric])")).to eql(['false'])
      end

      it 'undef is not an instance of Init[Numeric]' do
        expect(eval_and_collect_notices("notice(undef =~ Init[Numeric])")).to eql(['false'])
      end

      %w(0 1 0634 0x3b -0xba 0b1001 +0b1111 23.14 -2.3 2e-21 1.23e18  -0.23e18).each do |str|
        it "string '#{str}' is an instance of Init[Float]" do
          expect(eval_and_collect_notices("notice('#{str}' =~ Init[Float])")).to eql(['true'])
        end
      end

      it 'non numeric string is not an instance of Init[Float]' do
        expect(eval_and_collect_notices("notice('blue' =~ Init[Float])")).to eql(['false'])
      end

      it 'empty string is not an instance of Init[Float]' do
        expect(eval_and_collect_notices("notice('' =~ Init[Float])")).to eql(['false'])
      end

      it 'undef is not an instance of Init[Float]' do
        expect(eval_and_collect_notices("notice(undef =~ Init[Float])")).to eql(['false'])
      end

      %w(0 1 0634 0x3b -0xba 0b1001 0b1111).each do |str|
        it "string '#{str}' is an instance of Init[Integer]" do
          expect(eval_and_collect_notices("notice('#{str}' =~ Init[Integer])")).to eql(['true'])
        end
      end

      %w(23.14 -2.3 2e-21 1.23e18  -0.23e18).each do |str|
        it "valid float string '#{str}' is not an instance of Init[Integer]" do
          expect(eval_and_collect_notices("notice('#{str}' =~ Init[Integer])")).to eql(['false'])
        end
      end

      it 'non numeric string is not an instance of Init[Integer]' do
        expect(eval_and_collect_notices("notice('blue' =~ Init[Integer])")).to eql(['false'])
      end

      it 'empty string is not an instance of Init[Integer]' do
        expect(eval_and_collect_notices("notice('' =~ Init[Integer])")).to eql(['false'])
      end

      it 'undef is not an instance of Init[Integer]' do
        expect(eval_and_collect_notices("notice(undef =~ Init[Integer])")).to eql(['false'])
      end

      %w(1.2.3 1.1.1-a3 1.2.3+b3 1.2.3-a3+b3).each do |str|
        it "string '#{str}' is an instance of Init[SemVer]" do
          expect(eval_and_collect_notices("notice('#{str}' =~ Init[SemVer])")).to eql(['true'])
        end
      end

      it 'non SemVer compliant string is not an instance of Init[SemVer]' do
        expect(eval_and_collect_notices("notice('blue' =~ Init[SemVer])")).to eql(['false'])
      end

      it 'empty string is not an instance of Init[SemVer]' do
        expect(eval_and_collect_notices("notice('' =~ Init[SemVer])")).to eql(['false'])
      end

      it 'undef is not an instance of Init[SemVer]' do
        expect(eval_and_collect_notices("notice(undef =~ Init[SemVer])")).to eql(['false'])
      end
    end
  end
end
end
end
