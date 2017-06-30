require 'spec_helper'
require 'puppet/pops'
require 'puppet_spec/compiler'

module Puppet::Pops
module Types
describe 'Sensitive Type' do
  include PuppetSpec::Compiler

  context 'as a type' do
    it 'can be created without a parameter with the type factory' do
      t = TypeFactory.sensitive
      expect(t).to be_a(PSensitiveType)
      expect(t).to eql(PSensitiveType::DEFAULT)
    end

    it 'can be created with a parameter with the type factory' do
      t = TypeFactory.sensitive(PIntegerType::DEFAULT)
      expect(t).to be_a(PSensitiveType)
      expect(t.type).to eql(PIntegerType::DEFAULT)
    end

    it 'string representation of unparameterized instance is "Sensitive"' do
      expect(PSensitiveType::DEFAULT.to_s).to eql('Sensitive')
    end

    context 'when used in Puppet expressions' do
      it 'is equal to itself only' do
        code = <<-CODE
          $t = Sensitive
          notice(Sensitive =~ Type[ Sensitive ])
          notice(Sensitive == Sensitive)
          notice(Sensitive < Sensitive)
          notice(Sensitive > Sensitive)
        CODE
        expect(eval_and_collect_notices(code)).to eq(['true', 'true', 'false', 'false'])
      end

      context "when parameterized" do
        it 'is equal other types with the same parameterization' do
          code = <<-CODE
            notice(Sensitive[String] == Sensitive[String])
            notice(Sensitive[Numeric] != Sensitive[Integer])
          CODE
          expect(eval_and_collect_notices(code)).to eq(['true', 'true'])
        end

        it 'orders parameterized types based on the type system hierarchy' do
          code = <<-CODE
            notice(Sensitive[Numeric] > Sensitive[Integer])
            notice(Sensitive[Numeric] < Sensitive[Integer])
          CODE
          expect(eval_and_collect_notices(code)).to eq(['true', 'false'])
        end

        it 'does not order incomparable parameterized types' do
          code = <<-CODE
            notice(Sensitive[String] < Sensitive[Integer])
            notice(Sensitive[String] > Sensitive[Integer])
          CODE
          expect(eval_and_collect_notices(code)).to eq(['false', 'false'])
        end

        it 'generalizes passed types to prevent information leakage' do
          code =<<-CODE
            $it = String[7, 7]
            $st = Sensitive[$it]
            notice(type($st))
          CODE
          expect(eval_and_collect_notices(code)).to eq(['Type[Sensitive[String]]'])
        end
      end
    end
  end

  context 'a Sensitive instance' do
    it 'can be created from a string and does not leak its contents' do
      code =<<-CODE
        $o = Sensitive("hunter2")
        notice($o)
        notice(type($o))
      CODE
      expect(eval_and_collect_notices(code)).to eq(['Sensitive [value redacted]', 'Sensitive[String]'])
    end

    it 'matches the appropriate parameterized type' do
      code =<<-CODE
        $o = Sensitive("hunter2")
        notice(assert_type(Sensitive[String], $o))
        notice(assert_type(Sensitive[String[7, 7]], $o))
      CODE
      expect(eval_and_collect_notices(code)).to eq(['Sensitive [value redacted]', 'Sensitive [value redacted]'])
    end

    it 'verifies the constrains of the parameterized type' do
      pending "the ability to enforce constraints without leaking information"
      code =<<-CODE
        $o = Sensitive("hunter2")
        notice(assert_type(Sensitive[String[10, 20]], $o))
      CODE
      expect {
        eval_and_collect_notices(code)
      }.to raise_error(Puppet::Error, /expects a Sensitive\[String\[10, 20\]\] value, got Sensitive\[String\[7, 7\]\]/)
    end

    it 'does not match an inappropriate parameterized type' do
      code =<<-CODE
        $o = Sensitive("hunter2")
        notice(assert_type(Sensitive[Integer], $o) |$expected, $actual| {
          "$expected != $actual"
        })
      CODE
      expect(eval_and_collect_notices(code)).to eq(['Sensitive[Integer] != Sensitive[String]'])
    end

    it 'can be created from another sensitive instance ' do
      code =<<-CODE
        $o = Sensitive("hunter2")
        $x = Sensitive($o)
        notice(assert_type(Sensitive[String], $x))
      CODE
      expect(eval_and_collect_notices(code)).to eq(['Sensitive [value redacted]'])
    end

    it 'can be given to a user defined resource as a parameter' do
      code =<<-CODE
        define keeper_of_secrets(Sensitive $x) {
          notice(assert_type(Sensitive[String], $x))
        }
        keeper_of_secrets { 'test': x => Sensitive("long toe") }
      CODE
      expect(eval_and_collect_notices(code)).to eq(['Sensitive [value redacted]'])
    end

    it 'can be given to a class as a parameter' do
      code =<<-CODE
        class keeper_of_secrets(Sensitive $x) {
          notice(assert_type(Sensitive[String], $x))
        }
        class { 'keeper_of_secrets': x => Sensitive("long toe") }
      CODE
      expect(eval_and_collect_notices(code)).to eq(['Sensitive [value redacted]'])
    end

    it 'can be given to a function as a parameter' do
      code =<<-CODE
        function keeper_of_secrets(Sensitive $x) {
          notice(assert_type(Sensitive[String], $x))
        }
        keeper_of_secrets(Sensitive("long toe"))
      CODE
      expect(eval_and_collect_notices(code)).to eq(['Sensitive [value redacted]'])
    end
  end

  it "enforces wrapped type constraints" do
    pending "the ability to enforce constraints without leaking information"
    code =<<-CODE
        class secrets_handler(Sensitive[Array[String[4, 8]]] $pwlist) {
            notice($pwlist)
        }

        class { "secrets_handler":
            pwlist => Sensitive(['hi', 'longlonglong'])
        }
    CODE
    expect {
      expect(eval_and_collect_notices(code))
    }.to raise_error(Puppet::Error, /expects a String\[4, 8\], got String/)
  end
end
end
end
