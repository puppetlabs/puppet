require 'spec_helper'
require 'puppet_spec/files'
require 'puppet_spec/compiler'

require 'puppet/face'

describe 'when pcore described resources types are in use' do
  include PuppetSpec::Files
  include PuppetSpec::Compiler

  let(:genface) { Puppet::Face[:generate, :current] }

  context "in an environment with two modules" do
    let(:dir) do
      dir_containing('environments', { 'production' => {
        'environment.conf' => "modulepath = modules",
        'manifests' => { 'site.pp' => "" },
        'modules' => {
          'm1' => {
            'lib' => { 'puppet' => { 'type' => {
              'test1.rb' => <<-EOF
              module Puppet
              Type.newtype(:test1) do
                @doc = "Docs for resource"
                newproperty(:message) do
                  desc "Docs for 'message' property"
                end
                newparam(:name) do
                  desc "Docs for 'name' parameter"
                  isnamevar
                end
                newparam(:whatever) do
                  desc "Docs for 'whatever' parameter"
                end
              end; end
              EOF
             } }
          },
        },
        'm2' => {
          'lib' => { 'puppet' => { 'type' => {
            'test2.rb' => <<-EOF,
            module Puppet
            Type.newtype(:test2) do
              @doc = "Docs for resource"
              @isomorphic = false
              newproperty(:message) do
                desc "Docs for 'message' property"
              end
              newparam(:name) do
                desc "Docs for 'name' parameter"
                isnamevar
              end
              newparam(:color) do
                desc "Docs for 'color' parameter"
                newvalues(:red, :green, :blue, /#[0-9A-Z]{6}/)
              end
            end;end
            EOF
            'test3.rb' => <<-RUBY,
              Puppet::Type.newtype(:test3) do
                newproperty(:message)
                newparam(:a) { isnamevar }
                newparam(:b) { isnamevar }
                newparam(:c) { isnamevar }
                def self.title_patterns
                  [ [ /^((.+)\\/(.*))$/,  [[:a], [:b], [:c]]] ]
                end
              end
            RUBY
            'cap.rb' => <<-EOF
            module Puppet
            Type.newtype(:cap, :is_capability => true) do
              @doc = "Docs for capability"
              @isomorphic = false
              newproperty(:message) do
                desc "Docs for 'message' property"
              end
            end;end
            EOF
           } } },
        }
      }}})
    end

    let(:modulepath) do
      File.join(dir, 'production', 'modules')
    end

    let(:m1) do
      File.join(modulepath, 'm1')
    end

    let(:m2) do
      File.join(modulepath, 'm2')
    end

    let(:outputdir) do
      File.join(dir, 'production', '.resource_types')
    end

    around(:each) do |example|
      Puppet.settings.initialize_global_settings
      Puppet[:manifest] = ''
      loader = Puppet::Environments::Directories.new(dir, [])
      Puppet.override(:environments => loader) do
        Puppet.override(:current_environment => loader.get('production')) do
          example.run
        end
      end
    end

    it 'can use generated types to compile a catalog' do
      genface.types
      catalog = compile_to_catalog(<<-MANIFEST)
        test1 { 'a':
          message => 'a works'
        }
        # Several instances of the type can be created - implicit test
        test1 { 'another a':
          message => 'another a works'
        }
        test2 { 'b':
          message => 'b works'
        }
        test3 { 'x/y':
          message => 'x/y works'
        }
        cap { 'c':
          message => 'c works'
        }
      MANIFEST
      expect(catalog.resource(:test1, "a")['message']).to eq('a works')
      expect(catalog.resource(:test2, "b")['message']).to eq('b works')
      expect(catalog.resource(:test3, "x/y")['message']).to eq('x/y works')
      expect(catalog.resource(:cap, "c")['message']).to eq('c works')
    end

    it 'the validity of attribute names are checked' do
      genface.types
      expect do
        compile_to_catalog(<<-MANIFEST)
          test1 { 'a':
            mezzage => 'a works'
          }
        MANIFEST
      end.to raise_error(/no parameter named 'mezzage'/)
    end

    it 'meta-parameters such as noop can be used' do
      genface.types
      catalog = compile_to_catalog(<<-MANIFEST)
        test1 { 'a':
          message => 'noop works',
          noop => true
        }
      MANIFEST
      expect(catalog.resource(:test1, "a")['noop']).to eq(true)
    end

    it 'capability is propagated to the catalog' do
      genface.types
      catalog = compile_to_catalog(<<-MANIFEST)
        test2 { 'r':
          message => 'a resource'
        }
        cap { 'c':
          message => 'a cap'
        }
      MANIFEST
      expect(catalog.resource(:test2, "r").is_capability?).to eq(false)
      expect(catalog.resource(:cap, "c").is_capability?).to eq(true)
    end

    it 'a generated type describes if it is isomorphic' do
      generate_and_in_a_compilers_context do |compiler|
        t1 = find_resource_type(compiler.topscope, 'test1')
        expect(t1.isomorphic?).to be(true)
        t2 = find_resource_type(compiler.topscope, 'test2')
        expect(t2.isomorphic?).to be(false)
      end
    end

    it 'a generated type describes if it is a capability' do
      generate_and_in_a_compilers_context do |compiler|
        t1 = find_resource_type(compiler.topscope, 'test1')
        expect(t1.is_capability?).to be(false)
        t2 = find_resource_type(compiler.topscope, 'cap')
        expect(t2.is_capability?).to be(true)
      end
    end

    it 'a generated type returns parameters defined in pcore' do
      generate_and_in_a_compilers_context do |compiler|
        t1 = find_resource_type(compiler.topscope, 'test1')
        expect(t1.parameters.size).to be(2)
        expect(t1.parameters[0].name).to eql('name')
        expect(t1.parameters[1].name).to eql('whatever')
      end
    end

    it 'a generated type picks up and returns if a parameter is a namevar' do
      generate_and_in_a_compilers_context do |compiler|
        t1 = find_resource_type(compiler.topscope, 'test1')
        expect(t1.parameters[0].name_var).to be(true)
        expect(t1.parameters[1].name_var).to be(false)
      end
    end

    it 'a generated type returns properties defined in pcore' do
      generate_and_in_a_compilers_context do |compiler|
        t1 = find_resource_type(compiler.topscope, 'test1')
        expect(t1.properties.size).to be(1)
        expect(t1.properties[0].name).to eql('message')
      end
    end

    it 'a generated type returns [[/(.*)/m, <first attr>]] as default title_pattern when there is a namevar but no pattern specified' do
      generate_and_in_a_compilers_context do |compiler|
        t1 = find_resource_type(compiler.topscope, 'test1')
        expect(t1.title_patterns.size).to be(1)
        expect(t1.title_patterns[0][0]).to eql(/(?m-ix:(.*))/)
      end
    end

    it "the compiler asserts the type of parameters" do
      pending "assertion of parameter types not yet implemented"
      genface.types
      expect {
      compile_to_catalog(<<-MANIFEST)
        test2 { 'b':
          color => 'white is not a color'
        }
      MANIFEST
      }.to raise_error(/an error indicating that color cannot have that value/) # ERROR TBD.
    end
  end

  def find_resource_type(scope, name)
    Puppet::Pops::Evaluator::Runtime3ResourceSupport.find_resource_type(scope, name)
  end

  def generate_and_in_a_compilers_context(&block)
    genface.types
    # Since an instance of a compiler is needed and it starts an initial import that evaluates
    # code, and that code will be loaded from manifests with a glob (go figure)
    # the only way to stop that is to set 'code' to something as that overrides "importing" files.
    Puppet[:code] = "undef"
    node = Puppet::Node.new('test')
    # All loading must be done in a context configured as the compiler does it.
    # (Therefore: use the context a compiler creates as this test logic must otherwise
    #  know how to do this).
    #
    compiler = Puppet::Parser::Compiler.new(node)
    Puppet::override(compiler.context_overrides) do
      block.call(compiler)
    end
  end

end
