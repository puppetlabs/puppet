require 'spec_helper'
require 'puppet/pops'
require 'puppet_spec/compiler'
require 'puppet/pops/types/ruby_generator'

def root_binding
  return binding
end

module Puppet::Pops
module Types
describe 'Puppet Ruby Generator' do
  include PuppetSpec::Compiler

  let!(:parser) { TypeParser.singleton }
  let(:generator) { RubyGenerator.new }

  context 'when generating classes for Objects having attribute names that are Ruby reserved words' do
    let (:source) { <<-PUPPET }
      type MyObject = Object[{
        attributes => {
          alias => String,
          begin => String,
          break => String,
          def => String,
          do => String,
          end => String,
          ensure => String,
          for => String,
          module => String,
          next => String,
          nil => String,
          not => String,
          redo => String,
          rescue => String,
          retry => String,
          return => String,
          self => String,
          super => String,
          then => String,
          until => String,
          when => String,
          while => String,
          yield => String,
        },
      }]
      $x = MyObject({
        alias => 'value of alias',
        begin => 'value of begin',
        break => 'value of break',
        def => 'value of def',
        do => 'value of do',
        end => 'value of end',
        ensure => 'value of ensure',
        for => 'value of for',
        module => 'value of module',
        next => 'value of next',
        nil => 'value of nil',
        not => 'value of not',
        redo => 'value of redo',
        rescue => 'value of rescue',
        retry => 'value of retry',
        return => 'value of return',
        self => 'value of self',
        super => 'value of super',
        then => 'value of then',
        until => 'value of until',
        when => 'value of when',
        while => 'value of while',
        yield => 'value of yield',
      })
      notice($x.alias)
      notice($x.begin)
      notice($x.break)
      notice($x.def)
      notice($x.do)
      notice($x.end)
      notice($x.ensure)
      notice($x.for)
      notice($x.module)
      notice($x.next)
      notice($x.nil)
      notice($x.not)
      notice($x.redo)
      notice($x.rescue)
      notice($x.retry)
      notice($x.return)
      notice($x.self)
      notice($x.super)
      notice($x.then)
      notice($x.until)
      notice($x.when)
      notice($x.while)
      notice($x.yield)
    PUPPET

    it 'can create an instance and access all attributes' do
      expect(eval_and_collect_notices(source)).to eql([
        'value of alias',
        'value of begin',
        'value of break',
        'value of def',
        'value of do',
        'value of end',
        'value of ensure',
        'value of for',
        'value of module',
        'value of next',
        'value of nil',
        'value of not',
        'value of redo',
        'value of rescue',
        'value of retry',
        'value of return',
        'value of self',
        'value of super',
        'value of then',
        'value of until',
        'value of when',
        'value of while',
        'value of yield',
      ])
    end
  end

  context 'when generating classes for Objects having function names that are Ruby reserved words' do
    let (:source) { <<-PUPPET }
      type MyObject = Object[{
        functions => {
          alias  => { type => Callable[[0,0],String], annotations => {RubyMethod => { 'body' => "'value of alias'" }}},
          begin  => { type => Callable[[0,0],String], annotations => {RubyMethod => { 'body' => "'value of begin'" }}},
          break  => { type => Callable[[0,0],String], annotations => {RubyMethod => { 'body' => "'value of break'" }}},
          def    => { type => Callable[[0,0],String], annotations => {RubyMethod => { 'body' => "'value of def'" }}},
          do     => { type => Callable[[0,0],String], annotations => {RubyMethod => { 'body' => "'value of do'" }}},
          end    => { type => Callable[[0,0],String], annotations => {RubyMethod => { 'body' => "'value of end'" }}},
          ensure => { type => Callable[[0,0],String], annotations => {RubyMethod => { 'body' => "'value of ensure'" }}},
          for    => { type => Callable[[0,0],String], annotations => {RubyMethod => { 'body' => "'value of for'" }}},
          module => { type => Callable[[0,0],String], annotations => {RubyMethod => { 'body' => "'value of module'" }}},
          next   => { type => Callable[[0,0],String], annotations => {RubyMethod => { 'body' => "'value of next'" }}},
          nil    => { type => Callable[[0,0],String], annotations => {RubyMethod => { 'body' => "'value of nil'" }}},
          not    => { type => Callable[[0,0],String], annotations => {RubyMethod => { 'body' => "'value of not'" }}},
          redo   => { type => Callable[[0,0],String], annotations => {RubyMethod => { 'body' => "'value of redo'" }}},
          rescue => { type => Callable[[0,0],String], annotations => {RubyMethod => { 'body' => "'value of rescue'" }}},
          retry  => { type => Callable[[0,0],String], annotations => {RubyMethod => { 'body' => "'value of retry'" }}},
          return => { type => Callable[[0,0],String], annotations => {RubyMethod => { 'body' => "'value of return'" }}},
          self   => { type => Callable[[0,0],String], annotations => {RubyMethod => { 'body' => "'value of self'" }}},
          super  => { type => Callable[[0,0],String], annotations => {RubyMethod => { 'body' => "'value of super'" }}},
          then   => { type => Callable[[0,0],String], annotations => {RubyMethod => { 'body' => "'value of then'" }}},
          until  => { type => Callable[[0,0],String], annotations => {RubyMethod => { 'body' => "'value of until'" }}},
          when   => { type => Callable[[0,0],String], annotations => {RubyMethod => { 'body' => "'value of when'" }}},
          while  => { type => Callable[[0,0],String], annotations => {RubyMethod => { 'body' => "'value of while'" }}},
          yield  => { type => Callable[[0,0],String], annotations => {RubyMethod => { 'body' => "'value of yield'" }}},
        },
      }]
      $x = MyObject()
      notice($x.alias)
      notice($x.begin)
      notice($x.break)
      notice($x.def)
      notice($x.do)
      notice($x.end)
      notice($x.ensure)
      notice($x.for)
      notice($x.module)
      notice($x.next)
      notice($x.nil)
      notice($x.not)
      notice($x.redo)
      notice($x.rescue)
      notice($x.retry)
      notice($x.return)
      notice($x.self)
      notice($x.super)
      notice($x.then)
      notice($x.until)
      notice($x.when)
      notice($x.while)
      notice($x.yield)
    PUPPET

    it 'can create an instance and call all functions' do
      expect(eval_and_collect_notices(source)).to eql([
        'value of alias',
        'value of begin',
        'value of break',
        'value of def',
        'value of do',
        'value of end',
        'value of ensure',
        'value of for',
        'value of module',
        'value of next',
        'value of nil',
        'value of not',
        'value of redo',
        'value of rescue',
        'value of retry',
        'value of return',
        'value of self',
        'value of super',
        'value of then',
        'value of until',
        'value of when',
        'value of while',
        'value of yield',
      ])
    end
  end

  context 'when generating from Object types' do
    let (:type_decls) { <<-CODE.unindent }
      type MyModule::FirstGenerated = Object[{
        attributes => {
          name => String,
          age  => { type => Integer, value => 30 },
          what => { type => String, value => 'what is this', kind => constant },
          uc_name => {
            type => String,
            kind => derived,
            annotations => {
              RubyMethod => { body => '@name.upcase' }
            }
          },
          other_name => {
            type => String,
            kind => derived
          },
        },
        functions => {
          some_other => {
            type => Callable[1,1]
          },
          name_and_age => {
            type => Callable[1,1],
            annotations => {
              RubyMethod => {
                parameters => 'joiner',
                body => '"\#{@name}\#{joiner}\#{@age}"'
              }
            }
          },
          '[]' => {
            type => Callable[1,1],
            annotations => {
              RubyMethod => {
                parameters => 'key',
                body => @(EOF)
                  case key
                  when 'name'
                    name
                  when 'age'
                    age
                  else
                    nil
                  end
                |-EOF
              }
            }
          }
        }
      }]
      type MyModule::SecondGenerated = Object[{
        parent => MyModule::FirstGenerated,
        attributes => {
          address => String,
          zipcode => String,
          email => String,
          another => { type => Optional[MyModule::FirstGenerated], value => undef },
          number => Integer,
          aref => { type => Optional[MyModule::FirstGenerated], value => undef, kind => reference }
        }
      }]
      CODE

    let(:type_usage) { '' }
    let(:source) { type_decls + type_usage }

    context 'when generating anonymous classes' do

      loader = nil

      let(:first_type) { parser.parse('MyModule::FirstGenerated', loader) }
      let(:second_type) { parser.parse('MyModule::SecondGenerated', loader) }
      let(:first) { generator.create_class(first_type) }
      let(:second) { generator.create_class(second_type) }
      let(:notices) { [] }

      before(:each) do
        notices.concat(eval_and_collect_notices(source) do |topscope|
          loader = topscope.compiler.loaders.find_loader(nil)
        end)
      end

      context 'the generated class' do
        it 'inherits the PuppetObject module' do
          expect(first < PuppetObject).to be_truthy
        end

        it 'is the superclass of a generated subclass' do
          expect(second < first).to be_truthy
        end
      end

      context 'the #create class method' do
        it 'has an arity that reflects optional arguments' do
          expect(first.method(:create).arity).to eql(-2)
          expect(second.method(:create).arity).to eql(-6)
        end

        it 'creates an instance of the class' do
          inst = first.create('Bob Builder', 52)
          expect(inst).to be_a(first)
          expect(inst.name).to eq('Bob Builder')
          expect(inst.age).to eq(52)
        end

        it 'created instance has a [] method' do
          inst = first.create('Bob Builder', 52)
          expect(inst['name']).to eq('Bob Builder')
          expect(inst['age']).to eq(52)
        end

        it 'will perform type assertion of the arguments' do
          expect { first.create('Bob Builder', '52') }.to(
            raise_error(TypeAssertionError,
              'MyModule::FirstGenerated[age] has wrong type, expects an Integer value, got String')
          )
        end

        it 'will not accept nil as given value for an optional parameter that does not accept nil' do
          expect { first.create('Bob Builder', nil) }.to(
            raise_error(TypeAssertionError,
              'MyModule::FirstGenerated[age] has wrong type, expects an Integer value, got Undef')
          )
        end

        it 'reorders parameters to but the optional parameters last' do
          inst = second.create('Bob Builder', '42 Cool Street', '12345', 'bob@example.com', 23)
          expect(inst.name).to eq('Bob Builder')
          expect(inst.address).to eq('42 Cool Street')
          expect(inst.zipcode).to eq('12345')
          expect(inst.email).to eq('bob@example.com')
          expect(inst.number).to eq(23)
          expect(inst.what).to eql('what is this')
          expect(inst.age).to eql(30)
          expect(inst.another).to be_nil
        end

        it 'generates a code body for derived attribute from a RubyMethod body attribute' do
          inst = first.create('Bob Builder', 52)
          expect(inst.uc_name).to eq('BOB BUILDER')
        end

        it "generates a code body with 'not implemented' in the absense of a RubyMethod body attribute" do
          inst = first.create('Bob Builder', 52)
          expect { inst.other_name }.to raise_error(/no method is implemented for derived attribute MyModule::FirstGenerated\[other_name\]/)
        end

        it 'generates parameter list and a code body for derived function from a RubyMethod body attribute' do
          inst = first.create('Bob Builder', 52)
          expect(inst.name_and_age(' of age ')).to eq('Bob Builder of age 52')
        end
      end

      context 'the #from_hash class method' do
        it 'has an arity of one' do
          expect(first.method(:from_hash).arity).to eql(1)
          expect(second.method(:from_hash).arity).to eql(1)
        end

        it 'creates an instance of the class' do
          inst = first.from_hash('name' => 'Bob Builder', 'age' => 52)
          expect(inst).to be_a(first)
          expect(inst.name).to eq('Bob Builder')
          expect(inst.age).to eq(52)
        end

        it 'accepts an initializer where optional keys are missing' do
          inst = first.from_hash('name' => 'Bob Builder')
          expect(inst).to be_a(first)
          expect(inst.name).to eq('Bob Builder')
          expect(inst.age).to eq(30)
        end

        it 'does not accept an initializer where optional values are nil and type does not accept nil' do
          expect { first.from_hash('name' => 'Bob Builder', 'age' => nil) }.to(
            raise_error(TypeAssertionError,
              "MyModule::FirstGenerated initializer has wrong type, entry 'age' expects an Integer value, got Undef")
          )
        end
      end

      context 'creates an instance' do
        it 'that the TypeCalculator infers to the Object type' do
          expect(TypeCalculator.infer(first.from_hash('name' => 'Bob Builder'))).to eq(first_type)
        end

        it "where attributes of kind 'reference' are not considered part of #_pcore_all_contents" do
          inst = first.from_hash('name' => 'Bob Builder')
          wrinst = second.create('Bob Builder', '42 Cool Street', '12345', 'bob@example.com', 23, 40, inst, inst)
          results = []
          wrinst._pcore_all_contents([]) { |v| results << v }
          expect(results).to eq([inst])
        end
      end

      context 'when used from Puppet' do
        let(:type_usage) { <<-PUPPET.unindent }
          $i = MyModule::FirstGenerated('Bob Builder', 52)
          notice($i['name'])
          notice($i['age'])
        PUPPET

        it 'The [] method is present on a created instance' do
          expect(notices).to eql(['Bob Builder', '52'])
        end
      end
    end

    context 'when generating static code' do
      module_def = nil

      before(:each) do
        # Ideally, this would be in a before(:all) but that is impossible since lots of Puppet
        # environment specific settings are configured by the spec_helper in before(:each)
        if module_def.nil?
          first_type = nil
          second_type = nil
          eval_and_collect_notices(source) do
            first_type = parser.parse('MyModule::FirstGenerated')
            second_type = parser.parse('MyModule::SecondGenerated')

            Loaders.implementation_registry.register_type_mapping(
              PRuntimeType.new(:ruby, [/^PuppetSpec::RubyGenerator::(\w+)$/, 'MyModule::\1']),
              [/^MyModule::(\w+)$/, 'PuppetSpec::RubyGenerator::\1'])

            module_def = generator.module_definition([first_type, second_type], 'Generated stuff')
          end
          Loaders.clear
          Puppet[:code] = nil

          # Create the actual classes in the PuppetSpec::RubyGenerator module
          Puppet.override(:loaders => Puppet::Pops::Loaders.new(Puppet::Node::Environment.create(:testing, []))) do
            eval(module_def, root_binding)
          end
        end
      end

      after(:all) do
        # Don't want generated module to leak outside this test
        PuppetSpec.send(:remove_const, :RubyGenerator)
      end

      it 'the #_pcore_type class method returns a resolved Type' do
        first_type = PuppetSpec::RubyGenerator::FirstGenerated._pcore_type
        expect(first_type).to be_a(PObjectType)
        second_type = PuppetSpec::RubyGenerator::SecondGenerated._pcore_type
        expect(second_type).to be_a(PObjectType)
        expect(second_type.parent).to eql(first_type)
      end

      context 'the #create class method' do
        it 'has an arity that reflects optional arguments' do
          expect(PuppetSpec::RubyGenerator::FirstGenerated.method(:create).arity).to eql(-2)
          expect(PuppetSpec::RubyGenerator::SecondGenerated.method(:create).arity).to eql(-6)
        end

        it 'creates an instance of the class' do
          inst = PuppetSpec::RubyGenerator::FirstGenerated.create('Bob Builder', 52)
          expect(inst).to be_a(PuppetSpec::RubyGenerator::FirstGenerated)
          expect(inst.name).to eq('Bob Builder')
          expect(inst.age).to eq(52)
        end

        it 'will perform type assertion of the arguments' do
          expect { PuppetSpec::RubyGenerator::FirstGenerated.create('Bob Builder', '52') }.to(
            raise_error(TypeAssertionError,
              'MyModule::FirstGenerated[age] has wrong type, expects an Integer value, got String')
          )
        end

        it 'will not accept nil as given value for an optional parameter that does not accept nil' do
          expect { PuppetSpec::RubyGenerator::FirstGenerated.create('Bob Builder', nil) }.to(
            raise_error(TypeAssertionError,
              'MyModule::FirstGenerated[age] has wrong type, expects an Integer value, got Undef')
          )
        end

        it 'reorders parameters to but the optional parameters last' do
          inst = PuppetSpec::RubyGenerator::SecondGenerated.create('Bob Builder', '42 Cool Street', '12345', 'bob@example.com', 23)
          expect(inst.name).to eq('Bob Builder')
          expect(inst.address).to eq('42 Cool Street')
          expect(inst.zipcode).to eq('12345')
          expect(inst.email).to eq('bob@example.com')
          expect(inst.number).to eq(23)
          expect(inst.what).to eql('what is this')
          expect(inst.age).to eql(30)
          expect(inst.another).to be_nil
        end
      end

      context 'the #from_hash class method' do
        it 'has an arity of one' do
          expect(PuppetSpec::RubyGenerator::FirstGenerated.method(:from_hash).arity).to eql(1)
          expect(PuppetSpec::RubyGenerator::SecondGenerated.method(:from_hash).arity).to eql(1)
        end

        it 'creates an instance of the class' do
          inst = PuppetSpec::RubyGenerator::FirstGenerated.from_hash('name' => 'Bob Builder', 'age' => 52)
          expect(inst).to be_a(PuppetSpec::RubyGenerator::FirstGenerated)
          expect(inst.name).to eq('Bob Builder')
          expect(inst.age).to eq(52)
        end

        it 'accepts an initializer where optional keys are missing' do
          inst = PuppetSpec::RubyGenerator::FirstGenerated.from_hash('name' => 'Bob Builder')
          expect(inst).to be_a(PuppetSpec::RubyGenerator::FirstGenerated)
          expect(inst.name).to eq('Bob Builder')
          expect(inst.age).to eq(30)
        end

        it 'does not accept an initializer where optional values are nil and type does not accept nil' do
          expect { PuppetSpec::RubyGenerator::FirstGenerated.from_hash('name' => 'Bob Builder', 'age' => nil) }.to(
            raise_error(TypeAssertionError,
              "MyModule::FirstGenerated initializer has wrong type, entry 'age' expects an Integer value, got Undef")
          )
        end
      end
    end
  end

  context 'when generating from TypeSets' do
    def source
      <<-CODE
        type MyModule = TypeSet[{
          pcore_version => '1.0.0',
          version => '1.0.0',
          types   => {
            MyInteger => Integer,
            FirstGenerated => Object[{
              attributes => {
                name => String,
                age  => { type => Integer, value => 30 },
                what => { type => String, value => 'what is this', kind => constant }
              }
            }],
            SecondGenerated => Object[{
              parent => FirstGenerated,
              attributes => {
                address => String,
                zipcode => String,
                email => String,
                another => { type => Optional[FirstGenerated], value => undef },
                number => MyInteger
              }
            }]
          },
        }]

        type OtherModule = TypeSet[{
          pcore_version => '1.0.0',
          version => '1.0.0',
          types   => {
            MyFloat => Float,
            ThirdGenerated => Object[{
              attributes => {
                first => My::FirstGenerated
              }
            }],
            FourthGenerated => Object[{
              parent => My::SecondGenerated,
              attributes => {
                complex => { type => Optional[ThirdGenerated], value => undef },
                n1 => My::MyInteger,
                n2 => MyFloat
              }
            }]
          },
          references => {
            My => { name => 'MyModule', version_range => '1.x' }
          }
        }]
      CODE
    end

    context 'when generating anonymous classes' do

      typeset = nil

      let(:first_type) { typeset['My::FirstGenerated'] }
      let(:second_type) { typeset['My::SecondGenerated'] }
      let(:third_type) { typeset['ThirdGenerated'] }
      let(:fourth_type) { typeset['FourthGenerated'] }
      let(:first) { generator.create_class(first_type) }
      let(:second) { generator.create_class(second_type) }
      let(:third) { generator.create_class(third_type) }
      let(:fourth) { generator.create_class(fourth_type) }

      before(:each) do
        eval_and_collect_notices(source) do
          typeset = parser.parse('OtherModule')
        end
      end

      after(:each) { typeset = nil }

      context 'the typeset' do
        it 'produces expected string representation' do
          expect(typeset.to_s).to eq(
            "TypeSet[{pcore_version => '1.0.0', name_authority => 'http://puppet.com/2016.1/runtime', name => 'OtherModule', version => '1.0.0', types => {"+
              "MyFloat => Float, "+
              "ThirdGenerated => Object[{attributes => {'first' => My::FirstGenerated}}], "+
              "FourthGenerated => Object[{parent => My::SecondGenerated, attributes => {"+
                "'complex' => {type => Optional[ThirdGenerated], value => undef}, "+
                "'n1' => My::MyInteger, "+
                "'n2' => MyFloat"+
              "}}]}, references => {My => {'name' => 'MyModule', 'version_range' => '1.x'}}}]")
        end
      end

      context 'the generated class' do
        it 'inherits the PuppetObject module' do
          expect(first < PuppetObject).to be_truthy
        end

        it 'is the superclass of a generated subclass' do
          expect(second < first).to be_truthy
        end
      end

      context 'the #create class method' do
        it 'has an arity that reflects optional arguments' do
          expect(first.method(:create).arity).to eql(-2)
          expect(second.method(:create).arity).to eql(-6)
          expect(third.method(:create).arity).to eql(1)
          expect(fourth.method(:create).arity).to eql(-8)
        end

        it 'creates an instance of the class' do
          inst = first.create('Bob Builder', 52)
          expect(inst).to be_a(first)
          expect(inst.name).to eq('Bob Builder')
          expect(inst.age).to eq(52)
        end

        it 'will perform type assertion of the arguments' do
          expect { first.create('Bob Builder', '52') }.to(
            raise_error(TypeAssertionError,
              'MyModule::FirstGenerated[age] has wrong type, expects an Integer value, got String')
          )
        end

        it 'will not accept nil as given value for an optional parameter that does not accept nil' do
          expect { first.create('Bob Builder', nil) }.to(
            raise_error(TypeAssertionError,
              'MyModule::FirstGenerated[age] has wrong type, expects an Integer value, got Undef')
          )
        end

        it 'reorders parameters to but the optional parameters last' do
          inst = second.create('Bob Builder', '42 Cool Street', '12345', 'bob@example.com', 23)
          expect(inst.name).to eq('Bob Builder')
          expect(inst.address).to eq('42 Cool Street')
          expect(inst.zipcode).to eq('12345')
          expect(inst.email).to eq('bob@example.com')
          expect(inst.number).to eq(23)
          expect(inst.what).to eql('what is this')
          expect(inst.age).to eql(30)
          expect(inst.another).to be_nil
        end

        it 'two instances with the same attribute values are equal using #eql?' do
          inst1 = second.create('Bob Builder', '42 Cool Street', '12345', 'bob@example.com', 23)
          inst2 = second.create('Bob Builder', '42 Cool Street', '12345', 'bob@example.com', 23)
          expect(inst1.eql?(inst2)).to be_truthy
        end

        it 'two instances with the same attribute values are equal using #==' do
          inst1 = second.create('Bob Builder', '42 Cool Street', '12345', 'bob@example.com', 23)
          inst2 = second.create('Bob Builder', '42 Cool Street', '12345', 'bob@example.com', 23)
          expect(inst1 == inst2).to be_truthy
        end

        it 'two instances with the different attribute in super class values are different' do
          inst1 = second.create('Bob Builder', '42 Cool Street', '12345', 'bob@example.com', 23)
          inst2 = second.create('Bob Engineer', '42 Cool Street', '12345', 'bob@example.com', 23)
          expect(inst1 == inst2).to be_falsey
        end

        it 'two instances with the different attribute in sub class values are different' do
          inst1 = second.create('Bob Builder', '42 Cool Street', '12345', 'bob@example.com', 23)
          inst2 = second.create('Bob Builder', '42 Cool Street', '12345', 'bob@other.com', 23)
          expect(inst1 == inst2).to be_falsey
        end
      end

      context 'the #from_hash class method' do
        it 'has an arity of one' do
          expect(first.method(:from_hash).arity).to eql(1)
          expect(second.method(:from_hash).arity).to eql(1)
        end

        it 'creates an instance of the class' do
          inst = first.from_hash('name' => 'Bob Builder', 'age' => 52)
          expect(inst).to be_a(first)
          expect(inst.name).to eq('Bob Builder')
          expect(inst.age).to eq(52)
        end

        it 'accepts an initializer where optional keys are missing' do
          inst = first.from_hash('name' => 'Bob Builder')
          expect(inst).to be_a(first)
          expect(inst.name).to eq('Bob Builder')
          expect(inst.age).to eq(30)
        end

        it 'does not accept an initializer where optional values are nil and type does not accept nil' do
          expect { first.from_hash('name' => 'Bob Builder', 'age' => nil) }.to(
            raise_error(TypeAssertionError,
              "MyModule::FirstGenerated initializer has wrong type, entry 'age' expects an Integer value, got Undef")
          )
        end
      end

      context 'creates an instance' do
        it 'that the TypeCalculator infers to the Object type' do
          expect(TypeCalculator.infer(first.from_hash('name' => 'Bob Builder'))).to eq(first_type)
        end
      end
    end

    context 'when generating static code' do
      module_def = nil
      module_def2 = nil

      before(:each) do
        # Ideally, this would be in a before(:all) but that is impossible since lots of Puppet
        # environment specific settings are configured by the spec_helper in before(:each)
        if module_def.nil?
          eval_and_collect_notices(source) do
            typeset1 = parser.parse('MyModule')
            typeset2 = parser.parse('OtherModule')

            Loaders.implementation_registry.register_type_mapping(
              PRuntimeType.new(:ruby, [/^PuppetSpec::RubyGenerator::My::(\w+)$/, 'MyModule::\1']),
              [/^MyModule::(\w+)$/, 'PuppetSpec::RubyGenerator::My::\1'])

            Loaders.implementation_registry.register_type_mapping(
              PRuntimeType.new(:ruby, [/^PuppetSpec::RubyGenerator::Other::(\w+)$/, 'OtherModule::\1']),
              [/^OtherModule::(\w+)$/, 'PuppetSpec::RubyGenerator::Other::\1'])

            module_def = generator.module_definition_from_typeset(typeset1)
            module_def2 = generator.module_definition_from_typeset(typeset2)
          end
          Loaders.clear
          Puppet[:code] = nil

          # Create the actual classes in the PuppetSpec::RubyGenerator module
          Puppet.override(:loaders => Puppet::Pops::Loaders.new(Puppet::Node::Environment.create(:testing, []))) do
            eval(module_def, root_binding)
            eval(module_def2, root_binding)
          end
        end
      end

      after(:all) do
        # Don't want generated module to leak outside this test
        PuppetSpec.send(:remove_const, :RubyGenerator)
      end

      it 'the #_pcore_type class method returns a resolved Type' do
        first_type = PuppetSpec::RubyGenerator::My::FirstGenerated._pcore_type
        expect(first_type).to be_a(PObjectType)
        second_type = PuppetSpec::RubyGenerator::My::SecondGenerated._pcore_type
        expect(second_type).to be_a(PObjectType)
        expect(second_type.parent).to eql(first_type)
      end

      context 'the #create class method' do
        it 'has an arity that reflects optional arguments' do
          expect(PuppetSpec::RubyGenerator::My::FirstGenerated.method(:create).arity).to eql(-2)
          expect(PuppetSpec::RubyGenerator::My::SecondGenerated.method(:create).arity).to eql(-6)
        end

        it 'creates an instance of the class' do
          inst = PuppetSpec::RubyGenerator::My::FirstGenerated.create('Bob Builder', 52)
          expect(inst).to be_a(PuppetSpec::RubyGenerator::My::FirstGenerated)
          expect(inst.name).to eq('Bob Builder')
          expect(inst.age).to eq(52)
        end

        it 'will perform type assertion of the arguments' do
          expect { PuppetSpec::RubyGenerator::My::FirstGenerated.create('Bob Builder', '52') }.to(
            raise_error(TypeAssertionError,
              'MyModule::FirstGenerated[age] has wrong type, expects an Integer value, got String')
          )
        end

        it 'will not accept nil as given value for an optional parameter that does not accept nil' do
          expect { PuppetSpec::RubyGenerator::My::FirstGenerated.create('Bob Builder', nil) }.to(
            raise_error(TypeAssertionError,
              'MyModule::FirstGenerated[age] has wrong type, expects an Integer value, got Undef')
          )
        end

        it 'reorders parameters to but the optional parameters last' do
          inst = PuppetSpec::RubyGenerator::My::SecondGenerated.create('Bob Builder', '42 Cool Street', '12345', 'bob@example.com', 23)
          expect(inst.name).to eq('Bob Builder')
          expect(inst.address).to eq('42 Cool Street')
          expect(inst.zipcode).to eq('12345')
          expect(inst.email).to eq('bob@example.com')
          expect(inst.number).to eq(23)
          expect(inst.what).to eql('what is this')
          expect(inst.age).to eql(30)
          expect(inst.another).to be_nil
        end

        it 'two instances with the same attribute values are equal using #eql?' do
          inst1 = PuppetSpec::RubyGenerator::My::SecondGenerated.create('Bob Builder', '42 Cool Street', '12345', 'bob@example.com', 23)
          inst2 = PuppetSpec::RubyGenerator::My::SecondGenerated.create('Bob Builder', '42 Cool Street', '12345', 'bob@example.com', 23)
          expect(inst1.eql?(inst2)).to be_truthy
        end

        it 'two instances with the same attribute values are equal using #==' do
          inst1 = PuppetSpec::RubyGenerator::My::SecondGenerated.create('Bob Builder', '42 Cool Street', '12345', 'bob@example.com', 23)
          inst2 = PuppetSpec::RubyGenerator::My::SecondGenerated.create('Bob Builder', '42 Cool Street', '12345', 'bob@example.com', 23)
          expect(inst1 == inst2).to be_truthy
        end

        it 'two instances with the different attribute in super class values are different' do
          inst1 = PuppetSpec::RubyGenerator::My::SecondGenerated.create('Bob Builder', '42 Cool Street', '12345', 'bob@example.com', 23)
          inst2 = PuppetSpec::RubyGenerator::My::SecondGenerated.create('Bob Engineer', '42 Cool Street', '12345', 'bob@example.com', 23)
          expect(inst1 == inst2).to be_falsey
        end

        it 'two instances with the different attribute in sub class values are different' do
          inst1 = PuppetSpec::RubyGenerator::My::SecondGenerated.create('Bob Builder', '42 Cool Street', '12345', 'bob@example.com', 23)
          inst2 = PuppetSpec::RubyGenerator::My::SecondGenerated.create('Bob Builder', '42 Cool Street', '12345', 'bob@other.com', 23)
          expect(inst1 == inst2).to be_falsey
        end
      end

      context 'the #from_hash class method' do
        it 'has an arity of one' do
          expect(PuppetSpec::RubyGenerator::My::FirstGenerated.method(:from_hash).arity).to eql(1)
          expect(PuppetSpec::RubyGenerator::My::SecondGenerated.method(:from_hash).arity).to eql(1)
        end

        it 'creates an instance of the class' do
          inst = PuppetSpec::RubyGenerator::My::FirstGenerated.from_hash('name' => 'Bob Builder', 'age' => 52)
          expect(inst).to be_a(PuppetSpec::RubyGenerator::My::FirstGenerated)
          expect(inst.name).to eq('Bob Builder')
          expect(inst.age).to eq(52)
        end

        it 'accepts an initializer where optional keys are missing' do
          inst = PuppetSpec::RubyGenerator::My::FirstGenerated.from_hash('name' => 'Bob Builder')
          expect(inst).to be_a(PuppetSpec::RubyGenerator::My::FirstGenerated)
          expect(inst.name).to eq('Bob Builder')
          expect(inst.age).to eq(30)
        end

        it 'does not accept an initializer where optional values are nil and type does not accept nil' do
          expect { PuppetSpec::RubyGenerator::My::FirstGenerated.from_hash('name' => 'Bob Builder', 'age' => nil) }.to(
            raise_error(TypeAssertionError,
              "MyModule::FirstGenerated initializer has wrong type, entry 'age' expects an Integer value, got Undef")
          )
        end
      end
    end
  end
end
end
end
