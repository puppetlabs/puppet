require 'spec_helper'
require 'puppet/pops'
require 'puppet_spec/compiler'

module Puppet::Pops
  module Types
    describe 'The TypeSet Type' do
      include PuppetSpec::Compiler

      let(:parser) { TypeParser.singleton }
      let(:pp_parser) { Parser::EvaluatingParser.new }
      let(:env) { Puppet::Node::Environment.create('test', []) }
      let(:loaders) { Loaders.new(env) }
      let(:loader) { loaders.find_loader(nil) }

      def type_set_t(name, body_string, name_authority)
        init_literal_hash = pp_parser.parse_string("{#{body_string}}").body
        typeset = PTypeSetType.new(name, init_literal_hash, name_authority)
        loader.set_entry(Loader::TypedName.new(:type, name, name_authority), typeset)
        typeset
      end

      # Creates and parses an alias type declaration of a TypeSet, e.g.
      # ```
      # type <name> = TypeSet[{<body_string>}]
      # ```
      # The declaration implies the name authority {Pcore::RUNTIME_NAME_AUTHORITY}
      #
      # @param name [String] the name of the type set
      # @param body [String] the body (initialization hash) of the type-set
      # @return [PTypeSetType] the created type set
      def parse_type_set(name, body, name_authority = Pcore::RUNTIME_NAME_AUTHORITY)
        type_set_t(name, body, name_authority)
        parser.parse(name, loader)
      end

      context 'when validating the initialization hash' do
        context 'it will allow that it' do
          it 'has no types and no references' do
            ts = <<-OBJECT
            version => '1.0.0',
            pcore_version => '1.0.0',
            OBJECT
            expect { parse_type_set('MySet', ts) }.not_to raise_error
          end

          it 'has only references' do
            parse_type_set('FirstSet', <<-OBJECT)
              version => '1.0.0',
              pcore_version => '1.0.0',
              types => {
                Car => Object[{}]
              }
            OBJECT

            expect { parse_type_set('SecondSet', <<-OBJECT) }.not_to raise_error
              version => '1.0.0',
              pcore_version => '1.0.0',
              references => {
                First => {
                  name => 'FirstSet',
                  version_range => '1.x'
                }
              }
            OBJECT
          end

          it 'has multiple references to equally named TypeSets using different name authorities' do
            parse_type_set('FirstSet', <<-OBJECT, 'http://example.com/ns1')
              version => '1.0.0',
              pcore_version => '1.0.0',
              types => {
                Car => Object[{}]
              }
            OBJECT

            parse_type_set('FirstSet', <<-OBJECT, 'http://example.com/ns2')
              version => '1.0.0',
              pcore_version => '1.0.0',
              types => {
                Car => Object[{}]
              }
            OBJECT

            expect { parse_type_set('SecondSet', <<-OBJECT) }.not_to raise_error
              version => '1.0.0',
              pcore_version => '1.0.0',
              references => {
                First_1 => {
                  name_authority => 'http://example.com/ns1',
                  name => 'FirstSet',
                  version_range => '1.x'
                },
                First_2 => {
                  name => 'FirstSet',
                  name_authority => 'http://example.com/ns2',
                  version_range => '1.x'
                }
              }
            OBJECT
          end
        end

        context 'it raises an error when' do
          it 'pcore_version is missing' do
            ts = <<-OBJECT
            version => '1.0.0',
            OBJECT
            expect { parse_type_set('MySet', ts) }.to raise_error(TypeAssertionError,
              /expects a value for key 'pcore_version'/)
          end

          it 'the version is an invalid semantic version' do
            ts = <<-OBJECT
            version => '1.x',
            pcore_version => '1.0.0',
            OBJECT
            expect { parse_type_set('MySet', ts) }.to raise_error(SemanticPuppet::Version::ValidationFailure)
          end

          it 'the pcore_version is an invalid semantic version' do
            ts = <<-OBJECT
            version => '1.0.0',
            pcore_version => '1.x',
            OBJECT
            expect { parse_type_set('MySet', ts) }.to raise_error(SemanticPuppet::Version::ValidationFailure)
          end

          it 'the pcore_version is outside of the range of that is parsable by this runtime' do
            ts = <<-OBJECT
            version => '1.0.0',
            pcore_version => '2.0.0',
            OBJECT
            expect { parse_type_set('MySet', ts) }.to raise_error(ArgumentError,
              /The pcore version for TypeSet 'MySet' is not understood by this runtime. Expected range 1\.x, got 2\.0\.0/)
          end

          it 'the name authority is an invalid URI' do
            ts = <<-OBJECT
            version => '1.0.0',
            pcore_version => '1.0.0',
            name_authority => 'not a valid URI'
            OBJECT
            expect { parse_type_set('MySet', ts) }.to raise_error(TypeAssertionError,
              /entry 'name_authority' expects a match for Pattern\[.*\], got 'not a valid URI'/m)
          end

          context 'the types map' do
            it 'is empty' do
              ts = <<-OBJECT
                pcore_version => '1.0.0',
                version => '1.0.0',
                types => {}
              OBJECT
              expect { parse_type_set('MySet', ts) }.to raise_error(TypeAssertionError,
                /entry 'types' expects size to be at least 1, got 0/)
            end

            it 'is not a map' do
              ts = <<-OBJECT
                pcore_version => '1.0.0',
                version => '1.0.0',
                types => []
              OBJECT
              expect { parse_type_set('MySet', ts) }.to raise_error(Puppet::Error,
                /entry 'types' expects a Hash value, got Array/)
            end

            it 'contains values that are not types' do
              ts = <<-OBJECT
                pcore_version => '1.0.0',
                version => '1.0.0',
                types => {
                  Car => 'brum'
                }
              OBJECT
              expect { parse_type_set('MySet', ts) }.to raise_error(Puppet::Error,
                /The expression <'brum'> is not a valid type specification/)
            end

            it 'contains keys that are not SimpleNames' do
              ts = <<-OBJECT
                pcore_version => '1.0.0',
                version => '1.0.0',
                types => {
                  car => Integer
                }
              OBJECT
              expect { parse_type_set('MySet', ts) }.to raise_error(TypeAssertionError,
                /key of entry 'car' expects a match for Pattern\[\/\\A\[A-Z\]\\w\*\\z\/\], got 'car'/)
            end
          end

          context 'the references hash' do
            it 'is empty' do
              ts = <<-OBJECT
                pcore_version => '1.0.0',
                version => '1.0.0',
                references => {}
              OBJECT
              expect { parse_type_set('MySet', ts) }.to raise_error(TypeAssertionError,
                /entry 'references' expects size to be at least 1, got 0/)
            end

            it 'is not a hash' do
              ts = <<-OBJECT
                pcore_version => '1.0.0',
                version => '1.0.0',
                references => []
              OBJECT
              expect { parse_type_set('MySet', ts) }.to raise_error(TypeAssertionError,
                /entry 'references' expects a Hash value, got Array/)
            end

            it 'contains something other than reference initialization maps' do
              ts = <<-OBJECT
                pcore_version => '1.0.0',
                version => '1.0.0',
                references => {Ref => 2}
              OBJECT
              expect { parse_type_set('MySet', ts) }.to raise_error(TypeAssertionError,
                /entry 'references' entry 'Ref' expects a Struct value, got Integer/)
            end

            it 'contains several initialization that refers to the same TypeSet' do
              ts = <<-OBJECT
                pcore_version => '1.0.0',
                version => '1.0.0',
                references => {
                  A => { name => 'Vehicle::Cars', version_range => '1.x' },
                  V => { name => 'Vehicle::Cars', version_range => '1.x' },
                }
              OBJECT
              expect { parse_type_set('MySet', ts) }.to raise_error(ArgumentError,
                /references TypeSet 'http:\/\/puppet\.com\/2016\.1\/runtime\/Vehicle::Cars' more than once using overlapping version ranges/)
            end

            it 'contains an initialization maps with an alias that collides with a type name' do
              ts = <<-OBJECT
                pcore_version => '1.0.0',
                version => '1.0.0',
                types => {
                  Car => Object[{}]
                },
                references => {
                  Car => { name => 'Vehicle::Car', version_range => '1.x' }
                }
              OBJECT
              expect { parse_type_set('MySet', ts) }.to raise_error(ArgumentError,
                /references a TypeSet using alias 'Car'. The alias collides with the name of a declared type/)
            end

            context 'contains an initialization map that' do
              it 'has no version range' do
                ts = <<-OBJECT
                  pcore_version => '1.0.0',
                  version => '1.0.0',
                  references => { Ref => { name => 'X' } }
                OBJECT
                expect { parse_type_set('MySet', ts) }.to raise_error(TypeAssertionError,
                  /entry 'references' entry 'Ref' expects a value for key 'version_range'/)
              end

              it 'has no name' do
                ts = <<-OBJECT
                  pcore_version => '1.0.0',
                  version => '1.0.0',
                  references => { Ref => { version_range => '1.x' } }
                OBJECT
                expect { parse_type_set('MySet', ts) }.to raise_error(TypeAssertionError,
                  /entry 'references' entry 'Ref' expects a value for key 'name'/)
              end

              it 'has a name that is not a QRef' do
                ts = <<-OBJECT
                  pcore_version => '1.0.0',
                  version => '1.0.0',
                  references => { Ref => { name => 'cars', version_range => '1.x' } }
                OBJECT
                expect { parse_type_set('MySet', ts) }.to raise_error(TypeAssertionError,
                  /entry 'references' entry 'Ref' entry 'name' expects a match for Pattern\[\/\\A\[A-Z\]\[\\w\]\*\(\?:::\[A-Z\]\[\\w\]\*\)\*\\z\/\], got 'cars'/)
              end

              it 'has a version_range that is not a valid SemVer range' do
                ts = <<-OBJECT
                  pcore_version => '1.0.0',
                  version => '1.0.0',
                  references => { Ref => { name => 'Cars', version_range => 'N' } }
                OBJECT
                expect { parse_type_set('MySet', ts) }.to raise_error(ArgumentError,
                  /Unparsable version range: "N"/)
              end

              it 'has an alias that is not a SimpleName' do
                ts = <<-OBJECT
                  pcore_version => '1.0.0',
                  version => '1.0.0',
                  references => { 'cars' => { name => 'X', version_range => '1.x' } }
                OBJECT
                expect { parse_type_set('MySet', ts) }.to raise_error(TypeAssertionError,
                  /entry 'references' key of entry 'cars' expects a match for Pattern\[\/\\A\[A-Z\]\\w\*\\z\/\], got 'cars'/)
              end
            end
          end
        end
      end

      context 'when declaring types' do
        it 'can declare a type Alias' do
          expect { parse_type_set('TheSet', <<-OBJECT) }.not_to raise_error
            version => '1.0.0',
            pcore_version => '1.0.0',
            types => { PositiveInt => Integer[0, default] }
          OBJECT
        end

        it 'can declare an Object type using Object[{}]' do
          expect { parse_type_set('TheSet', <<-OBJECT) }.not_to raise_error
            version => '1.0.0',
            pcore_version => '1.0.0',
            types => { Complex => Object[{}] }
          OBJECT
        end

        it 'can declare an Object type that references other types in the same set' do
          expect { parse_type_set('TheSet', <<-OBJECT) }.not_to raise_error
            version => '1.0.0',
            pcore_version => '1.0.0',
            types => {
              Real => Float,
              Complex => Object[{
                attributes => {
                  real => Real,
                  imaginary => Real
                }
              }]
            }
          OBJECT
        end

        it 'can declare an alias that references itself' do
          expect { parse_type_set('TheSet', <<-OBJECT) }.not_to raise_error
            version => '1.0.0',
            pcore_version => '1.0.0',
            types => {
              Tree => Hash[String,Variant[String,Tree]]
            }
          OBJECT
        end

        it 'can declare a type that references types in another type set' do
          parse_type_set('Vehicles', <<-OBJECT)
              version => '1.0.0',
              pcore_version => '1.0.0',
              types => {
                Car => Object[{}],
                Bicycle => Object[{}]
              }
          OBJECT
          expect { parse_type_set('TheSet', <<-OBJECT) }.not_to raise_error
              version => '1.0.0',
              pcore_version => '1.0.0',
              types => {
                Transports => Variant[Vecs::Car,Vecs::Bicycle]
              },
              references => {
                Vecs => {
                  name => 'Vehicles',
                  version_range => '1.x'
                }
              }
          OBJECT
        end

        it 'can declare a type that references types in a type set referenced by another type set' do
          parse_type_set('Vehicles', <<-OBJECT)
              version => '1.0.0',
              pcore_version => '1.0.0',
              types => {
                Car => Object[{}],
                Bicycle => Object[{}]
              }
          OBJECT
          parse_type_set('Transports', <<-OBJECT)
              version => '1.0.0',
              pcore_version => '1.0.0',
              types => {
                Transports => Variant[Vecs::Car,Vecs::Bicycle]
              },
              references => {
                Vecs => {
                  name => 'Vehicles',
                  version_range => '1.x'
                }
              }
          OBJECT
          expect { parse_type_set('TheSet', <<-OBJECT) }.not_to raise_error
              version => '1.0.0',
              pcore_version => '1.0.0',
              types => {
                MotorPowered => Variant[T::Vecs::Car],
                Pedaled => Variant[T::Vecs::Bicycle],
                All => T::Transports
              },
              references => {
                T => {
                  name => 'Transports',
                  version_range => '1.x'
                }
              }
          OBJECT
        end

        context 'allows bracket-less form' do
          let(:logs) { [] }
          let(:notices) { logs.select { |log| log.level == :notice }.map { |log| log.message } }
          let(:warnings) { logs.select { |log| log.level == :warning }.map { |log| log.message } }
          let(:node) { Puppet::Node.new('example.com') }
          let(:compiler) { Puppet::Parser::Compiler.new(node) }

          def compile(code)
            Puppet[:code] = code
            Puppet::Util::Log.with_destination(Puppet::Test::LogCollector.new(logs)) { compiler.compile }
          end

          it 'on the TypeSet declaration itself' do
            compile(<<-PUPPET)
              type TS = TypeSet { pcore_version => '1.0.0' }
              notice(TS =~ Type[TypeSet])
            PUPPET
            expect(warnings).to be_empty
            expect(notices).to eql(['true'])
          end

          it 'without prefix on declared types (implies Object)' do
            compile(<<-PUPPET)
              type TS = TypeSet {
                pcore_version => '1.0.0',
                types => {
                  MyObject => { attributes => { a => Integer} }
                }
              }
              notice(TS =~ Type[TypeSet])
              notice(TS::MyObject =~ Type)
              notice(TS::MyObject(3))
            PUPPET
            expect(warnings).to be_empty
            expect(notices).to eql(['true', 'true', "TS::MyObject({'a' => 3})"])
          end

          it "prefixed with QREF 'Object' on declared types" do
            compile(<<-PUPPET)
              type TS = TypeSet {
                pcore_version => '1.0.0',
                types => {
                  MyObject => Object { attributes => { a => Integer} }
                }
              }
              notice(TS =~ Type[TypeSet])
              notice(TS::MyObject =~ Type)
              notice(TS::MyObject(3))
            PUPPET
            expect(warnings).to be_empty
            expect(notices).to eql(['true', 'true', "TS::MyObject({'a' => 3})"])
          end

          it 'prefixed with QREF to declare parent on declared types' do
            compile(<<-PUPPET)
              type TS = TypeSet {
                pcore_version => '1.0.0',
                types => {
                  MyObject => { attributes => { a => String }},
                  MySecondObject => MyObject { attributes => { b => String }}
                }
              }
              notice(TS =~ Type[TypeSet])
              notice(TS::MySecondObject =~ Type)
              notice(TS::MySecondObject < TS::MyObject)
              notice(TS::MyObject('hi'))
              notice(TS::MySecondObject('hello', 'world'))
            PUPPET
            expect(warnings).to be_empty
            expect(notices).to eql(
              ['true', 'true', 'true', "TS::MyObject({'a' => 'hi'})", "TS::MySecondObject({'a' => 'hello', 'b' => 'world'})"])
          end

          it 'and warns when parent is specified both before and inside the hash if strict == warning' do
            Puppet[:strict] = 'warning'
            compile(<<-PUPPET)
              type TS = TypeSet {
                pcore_version => '1.0.0',
                types => {
                  MyObject => { attributes => { a => String }},
                  MySecondObject => MyObject { parent => MyObject, attributes => { b => String }}
                }
              }
              notice(TS =~ Type[TypeSet])
            PUPPET
            expect(warnings).to eql(["The key 'parent' is declared more than once"])
            expect(notices).to eql(['true'])
          end

          it 'and errors when parent is specified both before and inside the hash if strict == error' do
            Puppet[:strict] = 'error'
            expect{ compile(<<-PUPPET) }.to raise_error(/The key 'parent' is declared more than once/)
              type TS = TypeSet {
                pcore_version => '1.0.0',
                types => {
                  MyObject => { attributes => { a => String }},
                  MySecondObject => MyObject { parent => MyObject, attributes => { b => String }}
                }
              }
              notice(TS =~ Type[TypeSet])
            PUPPET
          end
        end
      end

      it '#name_for method reports the name of deeply nested type correctly' do
        tv = parse_type_set('Vehicles', <<-OBJECT)
            version => '1.0.0',
            pcore_version => '1.0.0',
            types => { Car => Object[{}] }
        OBJECT
        parse_type_set('Transports', <<-OBJECT)
            version => '1.0.0',
            pcore_version => '1.0.0',
            references => {
              Vecs => {
                name => 'Vehicles',
                version_range => '1.x'
              }
            }
        OBJECT
        ts = parse_type_set('TheSet', <<-OBJECT)
            version => '1.0.0',
            pcore_version => '1.0.0',
            references => {
              T => {
                name => 'Transports',
                version_range => '1.x'
              }
            }
        OBJECT
        expect(ts.name_for(tv['Car'], nil)).to eql('T::Vecs::Car')
      end
    end
  end
end
