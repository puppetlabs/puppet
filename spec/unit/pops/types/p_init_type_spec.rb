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
  end
end
end
end
