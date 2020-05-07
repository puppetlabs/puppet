#! /usr/bin/env ruby
require 'spec_helper'
require 'puppet_spec/files'
require 'puppet_pal'

describe 'Puppet Pal' do
  include PuppetSpec::Files

  let(:testing_env) do
    {
      'pal_env' => {
        'functions' => functions,
        'lib' => { 'puppet' => lib_puppet },
        'manifests' => manifests,
        'modules' => modules,
        'plans' => plans,
        'tasks' => tasks,
        'types' => types,
      },
      'other_env1' => { 'modules' => {} },
      'other_env2' => { 'modules' => {} },
    }
  end

  let(:functions) { {} }
  let(:manifests) { {} }
  let(:modules) { {} }
  let(:plans) { {} }
  let(:lib_puppet) { {} }
  let(:tasks) { {} }
  let(:types) { {} }

  let(:environments_dir) { Puppet[:environmentpath] }

  let(:testing_env_dir) do
    dir_contained_in(environments_dir, testing_env)
    env_dir = File.join(environments_dir, 'pal_env')
    PuppetSpec::Files.record_tmp(env_dir)
    PuppetSpec::Files.record_tmp(File.join(environments_dir, 'other_env1'))
    PuppetSpec::Files.record_tmp(File.join(environments_dir, 'other_env2'))
    env_dir
  end

  let(:modules_dir) { File.join(testing_env_dir, 'modules') }

  # Without any facts - this speeds up the tests that do not require $facts to have any values
  let(:node_facts) { Hash.new }

  # TODO: to be used in examples for running in an existing env
  #  let(:env) { Puppet::Node::Environment.create(:testing, [modules_dir]) }

  context 'in general - without code in modules or env' do
    let(:modulepath) { [] }

    context "with a catalog compiler" do
      it 'errors if given both configured_by_env and manifest_file' do
        expect {
          Puppet::Pal.in_tmp_environment('pal_env', modulepath: modulepath, facts: node_facts) do |ctx|
            ctx.with_catalog_compiler(configured_by_env: true, manifest_file: 'undef.pp') {|c|  }
          end
        }.to raise_error(/manifest_file or code_string cannot be given when configured_by_env is true/)
      end

      it 'errors if given both configured_by_env and code_string' do
        expect {
          Puppet::Pal.in_tmp_environment('pal_env', modulepath: modulepath, facts: node_facts) do |ctx|
            ctx.with_catalog_compiler(configured_by_env: true, code_string: 'undef') {|c|  }
          end
        }.to raise_error(/manifest_file or code_string cannot be given when configured_by_env is true/)
      end

      context "evaluate_string method" do
        it 'evaluates code string in a given tmp environment' do
          result = Puppet::Pal.in_tmp_environment('pal_env', modulepath: modulepath, facts: node_facts) do |ctx|
            ctx.with_catalog_compiler {|c| c.evaluate_string('1+2+3') }
          end
          expect(result).to eq(6)
        end

        it 'can be evaluated more than once in a given tmp environment - each in fresh compiler' do
          Puppet::Pal.in_tmp_environment('pal_env', modulepath: modulepath, facts: node_facts) do |ctx|
            expect(  ctx.with_catalog_compiler {|c| c.evaluate_string('$a = 1+2+3')}).to eq(6)
            expect { ctx.with_catalog_compiler {|c| c.evaluate_string('$a') }}.to raise_error(/Unknown variable: 'a'/)
          end
        end

        it 'instantiates a function definition in the given code string' do
          result = Puppet::Pal.in_tmp_environment('pal_env', modulepath: modulepath, facts: node_facts) do |pal|
            pal.with_catalog_compiler do |compiler|
              compiler.evaluate_string(<<-CODE)
                function run_me() { "worked1" }
                run_me()
                CODE
            end
          end
          expect(result).to eq('worked1')
        end

        it 'instantiates a user defined resource definition in the given code string' do
          result = Puppet::Pal.in_tmp_environment('pal_env', modulepath: modulepath, facts: node_facts) do |pal|
            pal.with_catalog_compiler do |compiler|
              compiler.evaluate_string(<<-CODE)
                define run_me() { }
                run_me { test: }
                CODE
            end
          end
          resource = result[0]
          expect(resource).to be_a(Puppet::Pops::Types::PResourceType)
          expect(resource.type_name).to eq("Run_me")
          expect(resource.title).to eq('test')
        end

        context 'catalog_data_hash' do
          it 'produces a data_hash encoding of a catalog' do
            result = Puppet::Pal.in_tmp_environment('pal_env', modulepath: modulepath, facts: node_facts) do |pal|
              pal.with_catalog_compiler {|c|
                c.evaluate_string("notify {'test': message => /a regexp/}")
                c.catalog_data_hash
              }
            end
            expect(result['resources']).to include(include('type' => 'Notify'))
          end
        end

        context 'the with_json_encoding()' do

          it 'produces json for a catalog' do
            result = Puppet::Pal.in_tmp_environment('pal_env', modulepath: modulepath, facts: node_facts) do |pal|
              pal.with_catalog_compiler {|c|
                c.evaluate_string("notify {'test': message => /a regexp/}")
                c.with_json_encoding() {|encoder| encoder.encode }
              }
            end
            parsed = JSON.parse(result)
            expect(parsed['resources']).to include(include('type' => 'Notify'))
          end

          it 'produces pretty json by default' do
            result = Puppet::Pal.in_tmp_environment('pal_env', modulepath: modulepath, facts: node_facts) do |pal|
              pal.with_catalog_compiler {|c|
                c.evaluate_string("notify {'test': message => /a regexp/}")
                c.with_json_encoding() {|encoder| encoder.encode }
              }
            end
            expect(result.count("\n")).to be > 10
          end

          it 'produces compact (non pretty) json when pretty is false' do
            result = Puppet::Pal.in_tmp_environment('pal_env', modulepath: modulepath, facts: node_facts) do |pal|
              pal.with_catalog_compiler {|c|
                c.evaluate_string("notify {'test': message => /a regexp/}")
                c.with_json_encoding(pretty: false) {|encoder| encoder.encode }
              }
            end
            expect(result.count("\n")).to be < 10
          end

          it 'produces json for an individual resource by giving type and title to encode_resource()' do
            result = Puppet::Pal.in_tmp_environment('pal_env', modulepath: modulepath, facts: node_facts) do |pal|
              pal.with_catalog_compiler {|c|
                c.evaluate_string("notify {'test': message => 'yay'}")
                c.with_json_encoding() {|encoder| encoder.encode_resource('notify', 'test') }
              }
            end
            expect(result).to match(/"message":"yay"/)
          end

          it 'encodes values as rich data when needed' do
            result = Puppet::Pal.in_tmp_environment('pal_env', modulepath: modulepath, facts: node_facts) do |pal|
              pal.with_catalog_compiler {|c|
                c.evaluate_string("notify {'test': message => /a regexp/}")
                c.with_json_encoding(pretty: true) {|encoder| encoder.encode_resource('notify', 'test') }
              }
            end
            expect(result).to match(/"__ptype":"Regexp"/)
          end
        end
      end

      context "evaluate_file method" do
        it 'evaluates a manifest file in a given tmp environment' do
          result = Puppet::Pal.in_tmp_environment('pal_env', modulepath: modulepath, facts: node_facts) do |ctx|
            manifest = file_containing('testing.pp', "1+2+3+4")
            ctx.with_catalog_compiler {|c| c.evaluate_file(manifest) }
          end
          expect(result).to eq(10)
        end

        it 'instantiates definitions in the given code string' do
          result = Puppet::Pal.in_tmp_environment('pal_env', modulepath: modulepath, facts: node_facts) do |pal|
            pal.with_catalog_compiler do |compiler|
              manifest = file_containing('testing.pp', (<<-CODE))
                function run_me() { "worked1" }
                run_me()
                CODE
              pal.with_catalog_compiler {|c| c.evaluate_file(manifest) }
            end
          end
          expect(result).to eq('worked1')
        end
      end

      context "variables are supported such that" do
        it 'they can be set in any scope' do
          vars = {'a'=> 10, 'x::y' => 20}
          result = Puppet::Pal.in_tmp_environment('pal_env', modulepath: modulepath, facts: node_facts, variables: vars) do |ctx|
            ctx.with_catalog_compiler {|c| c.evaluate_string("1+2+3+4+$a+$x::y")}
          end
          expect(result).to eq(40)
        end

        it 'an error is raised if a variable name is illegal' do
          vars = {'_a::b'=> 10}
          expect do
            Puppet::Pal.in_tmp_environment('pal_env', modulepath: modulepath, facts: node_facts, variables: vars) do |ctx|
              manifest = file_containing('testing.pp', "ok")
              ctx.with_catalog_compiler {|c| c.evaluate_file(manifest) }
            end
          end.to raise_error(/has illegal name/)
        end

        it 'an error is raised if variable value is not RichData compliant' do
          vars = {'a'=> ArgumentError.new("not rich data")}
          expect do
            Puppet::Pal.in_tmp_environment('pal_env', modulepath: modulepath, facts: node_facts, variables: vars) do |ctx|
              ctx.with_catalog_compiler {|c|  }
            end
          end.to raise_error(/has illegal type - got: ArgumentError/)
        end

        it 'variable given to script_compiler overrides those given for environment' do
          vars = {'a'=> 10, 'x::y' => 20}
          result = Puppet::Pal.in_tmp_environment('pal_env', modulepath: modulepath, facts: node_facts, variables: vars) do |ctx|
            ctx.with_catalog_compiler(variables: {'x::y' => 40}) {|c| c.evaluate_string("1+2+3+4+$a+$x::y")}
          end
          expect(result).to eq(60)
        end
      end

      context "functions are supported such that" do
        it '"call_function" calls a function' do
          result = Puppet::Pal.in_tmp_environment('pal_env', modulepath: modulepath, facts: node_facts) do |ctx|
            manifest = file_containing('afunc.pp', "function myfunc($a) { $a * 2 } ")
            ctx.with_catalog_compiler(manifest_file: manifest) {|c| c.call_function('myfunc', 6) }
          end
          expect(result).to eq(12)
        end

        it '"call_function" accepts a call with a ruby block' do
          result = Puppet::Pal.in_tmp_environment('pal_env', modulepath: modulepath, facts: node_facts) do |ctx|
            ctx.with_catalog_compiler {|c| c.call_function('with', 6) {|x| x * 2} }
          end
          expect(result).to eq(12)
        end

        it '"function_signature" returns a signature of a function' do
          result = Puppet::Pal.in_tmp_environment('pal_env', modulepath: modulepath, facts: node_facts) do |ctx|
            manifest = file_containing('afunc.pp', "function myfunc(Integer $a) { $a * 2 } ")
            ctx.with_catalog_compiler(manifest_file: manifest) do |c|
              c.function_signature('myfunc')
            end
          end
          expect(result.class).to eq(Puppet::Pal::FunctionSignature)
        end

        it '"FunctionSignature#callable_with?" returns boolean if function is callable with given argument values' do
          result = Puppet::Pal.in_tmp_environment('pal_env', modulepath: modulepath, facts: node_facts) do |ctx|
            manifest = file_containing('afunc.pp', "function myfunc(Integer $a) { $a * 2 } ")
            ctx.with_catalog_compiler(manifest_file: manifest) do |c|
              signature = c.function_signature('myfunc')
              [ signature.callable_with?([10]),
                signature.callable_with?(['nope'])
              ]
            end
          end
          expect(result).to eq([true, false])
        end

        it '"FunctionSignature#callable_with?" calls a given lambda if there is an error' do
          result = Puppet::Pal.in_tmp_environment('pal_env', modulepath: modulepath, facts: node_facts) do |ctx|
            manifest = file_containing('afunc.pp', "function myfunc(Integer $a) { $a * 2 } ")
            ctx.with_catalog_compiler(manifest_file: manifest) do |c|
              signature = c.function_signature('myfunc')
              local_result = 'not yay'
              signature.callable_with?(['nope']) {|error| local_result = error }
              local_result
            end
          end
          expect(result).to match(/'myfunc' parameter 'a' expects an Integer value, got String/)
        end

        it '"FunctionSignature#callable_with?" does not call a given lambda when there is no error' do
          result = Puppet::Pal.in_tmp_environment('pal_env', modulepath: modulepath, facts: node_facts) do |ctx|
            manifest = file_containing('afunc.pp', "function myfunc(Integer $a) { $a * 2 } ")
            ctx.with_catalog_compiler(manifest_file: manifest) do |c|
              signature = c.function_signature('myfunc')
              local_result = 'yay'
              signature.callable_with?([10]) {|error| local_result = 'not yay' }
              local_result
            end
          end
          expect(result).to eq('yay')
        end

        it '"function_signature" gets the signatures from a ruby function with multiple dispatch' do
          result = Puppet::Pal.in_tmp_environment('pal_env', modulepath: modulepath, facts: node_facts) do |ctx|
            ctx.with_catalog_compiler {|c| c.function_signature('lookup') }
          end
          # check two different signatures of the lookup function
          expect(result.callable_with?(['key'])).to eq(true)
          expect(result.callable_with?(['key'], lambda() {|k| })).to eq(true)
        end

        it '"function_signature" returns nil if function is not found' do
          result = Puppet::Pal.in_tmp_environment('pal_env', modulepath: modulepath, facts: node_facts) do |ctx|
            ctx.with_catalog_compiler {|c| c.function_signature('no_where_to_be_found') }
          end
          expect(result).to eq(nil)
        end

        it '"FunctionSignature#callables" returns an array of callables' do
          result = Puppet::Pal.in_tmp_environment('pal_env', modulepath: modulepath, facts: node_facts) do |ctx|
            manifest = file_containing('afunc.pp', "function myfunc(Integer $a) { $a * 2 } ")
            ctx.with_catalog_compiler(manifest_file: manifest) do |c|
              c.function_signature('myfunc').callables
            end
          end
          expect(result.class).to eq(Array)
          expect(result.all? {|c| c.is_a?(Puppet::Pops::Types::PCallableType)}).to eq(true)
        end

        it '"list_functions" returns an array with all function names that can be loaded' do
          result = Puppet::Pal.in_tmp_environment('pal_env', modulepath: modulepath, facts: node_facts) do |ctx|
            ctx.with_catalog_compiler {|c| c.list_functions() }
          end
          expect(result.is_a?(Array)).to eq(true)
          expect(result.all? {|s| s.is_a?(Puppet::Pops::Loader::TypedName) }).to eq(true)
          # there are certainly more than 30 functions in puppet - (56 when writing this, but some refactoring
          # may take place, so don't want an exact number here - jsut make sure it found "all of them"
          expect(result.count).to be > 30
        end

        it '"list_functions" filters on name based on a given regexp' do
          result = Puppet::Pal.in_tmp_environment('pal_env', modulepath: modulepath, facts: node_facts) do |ctx|
            ctx.with_catalog_compiler {|c| c.list_functions(/epp/) }
          end
          expect(result.is_a?(Array)).to eq(true)
          expect(result.all? {|s| s.is_a?(Puppet::Pops::Loader::TypedName) }).to eq(true)
          # there are two functions currently that have 'epp' in their name
          expect(result.count).to eq(2)
        end

      end

      context 'supports puppet data types such that' do
        it '"type" parses and returns a Type from a string specification' do
          result = Puppet::Pal.in_tmp_environment('pal_env', modulepath: modulepath, facts: node_facts) do | ctx|
            manifest = file_containing('main.pp', "type MyType = Float")
            ctx.with_catalog_compiler(manifest_file: manifest) {|c| c.type('Variant[Integer, Boolean, MyType]') }
          end
          expect(result.is_a?(Puppet::Pops::Types::PVariantType)).to eq(true)
          expect(result.types.size).to eq(3)
          expect(result.instance?(3.14)).to eq(true)
        end

        it '"create" creates a new object from a puppet data type and args' do
          result = Puppet::Pal.in_tmp_environment('pal_env', modulepath: modulepath, facts: node_facts) do | ctx|
            ctx.with_catalog_compiler { |c| c.create(Puppet::Pops::Types::PIntegerType::DEFAULT, '0x10') }
          end
          expect(result).to eq(16)
        end

        it '"create" creates a new object from puppet data type in string form and args' do
          result = Puppet::Pal.in_tmp_environment('pal_env', modulepath: modulepath, facts: node_facts) do | ctx|
            ctx.with_catalog_compiler { |c| c.create('Integer', '010') }
          end
          expect(result).to eq(8)
        end
      end
    end

    context 'supports parsing such that' do
      it '"parse_string" parses a puppet language string' do
        result = Puppet::Pal.in_tmp_environment('pal_env', modulepath: modulepath, facts: node_facts) do | ctx|
          ctx.with_catalog_compiler { |c| c.parse_string('$a = 10') }
        end
        expect(result.class).to eq(Puppet::Pops::Model::Program)
      end

      {  nil      => Puppet::Error,
        '0xWAT'   => Puppet::ParseErrorWithIssue,
        '$0 = 1'  => Puppet::ParseErrorWithIssue,
        'else 32' => Puppet::ParseErrorWithIssue,
      }.each_pair do |input, error_class|
        it "'parse_string' raises an error for invalid input: '#{input}'" do
          expect {
          Puppet::Pal.in_tmp_environment('pal_env', modulepath: modulepath, facts: node_facts) do | ctx|
            ctx.with_catalog_compiler { |c| c.parse_string(input) }
          end
          }.to raise_error(error_class)
        end
      end

      it '"parse_file" parses a puppet language string' do
        result = Puppet::Pal.in_tmp_environment('pal_env', modulepath: modulepath, facts: node_facts) do | ctx|
          manifest = file_containing('main.pp', "$a = 10")
          ctx.with_catalog_compiler { |c| c.parse_file(manifest) }
        end
        expect(result.class).to eq(Puppet::Pops::Model::Program)
      end

      it "'parse_file' raises an error for invalid input: 'else 32'" do
        expect {
        Puppet::Pal.in_tmp_environment('pal_env', modulepath: modulepath, facts: node_facts) do | ctx|
          manifest = file_containing('main.pp', "else 32")
          ctx.with_catalog_compiler { |c| c.parse_file(manifest) }
        end
        }.to raise_error(Puppet::ParseErrorWithIssue)
      end

      it "'parse_file' raises an error for invalid input, file is not a string" do
        expect {
        Puppet::Pal.in_tmp_environment('pal_env', modulepath: modulepath, facts: node_facts) do | ctx|
          ctx.with_catalog_compiler { |c| c.parse_file(42) }
        end
        }.to raise_error(Puppet::Error)
      end

      it 'the "evaluate" method evaluates the parsed AST' do
        result = Puppet::Pal.in_tmp_environment('pal_env', modulepath: modulepath, facts: node_facts) do | ctx|
          ctx.with_catalog_compiler { |c| c.evaluate(c.parse_string('10 + 20')) }
        end
        expect(result).to eq(30)
      end

      it 'the "evaluate" method instantiates definitions when given a Program' do
        result = Puppet::Pal.in_tmp_environment('pal_env', modulepath: modulepath, facts: node_facts) do | ctx|
          ctx.with_catalog_compiler { |c| c.evaluate(c.parse_string('function foo() { "yay"}; foo()')) }
        end
        expect(result).to eq('yay')
      end

      it 'the "evaluate" method does not instantiates definitions when given ast other than Program' do
        expect do
          Puppet::Pal.in_tmp_environment('pal_env', modulepath: modulepath, facts: node_facts) do | ctx|
            ctx.with_catalog_compiler do |c|
              program= c.parse_string('function foo() { "yay"}; foo()')
              c.evaluate(program.body)
            end
          end
        end.to raise_error(/Unknown function: 'foo'/)
      end

      it 'the "evaluate_literal" method evaluates AST being a representation of a literal value' do
        result = Puppet::Pal.in_tmp_environment('pal_env', modulepath: modulepath, facts: node_facts) do | ctx|
          ctx.with_catalog_compiler { |c| c.evaluate_literal(c.parse_string('{10 => "hello"}')) }
        end
        expect(result).to eq({10 => 'hello'})
      end

      it 'the "evaluate_literal" method errors if ast is not representing a literal value' do
        expect do
          Puppet::Pal.in_tmp_environment('pal_env', modulepath: modulepath, facts: node_facts) do | ctx|
            ctx.with_catalog_compiler { |c| c.evaluate_literal(c.parse_string('{10+1 => "hello"}')) }
          end
        end.to raise_error(/does not represent a literal value/)
      end

      it 'the "evaluate_literal" method errors if ast contains definitions' do
        expect do
          Puppet::Pal.in_tmp_environment('pal_env', modulepath: modulepath, facts: node_facts) do | ctx|
            ctx.with_catalog_compiler { |c| c.evaluate_literal(c.parse_string('function foo() { }; 42')) }
          end
        end.to raise_error(/does not represent a literal value/)
      end

      it 'the "evaluate" method evaluates but does not evaluate lazy constructs' do
        result = Puppet::Pal.in_tmp_environment('pal_env', modulepath: modulepath, facts: node_facts) do | ctx|
          ctx.with_catalog_compiler do |c|
            c.evaluate(c.parse_string('define foo() { notify {nope: }} foo { test: }'))
            c.with_json_encoding() {|encoder| encoder.encode }
          end
        end
        parsed = JSON.parse(result)
        expect(parsed['resources']).to_not include(include('type' => 'Notify'))
      end

      it 'an "evaluate" followed by "compile_additions" evaluates lazy constructs' do
        result = Puppet::Pal.in_tmp_environment('pal_env', modulepath: modulepath, facts: node_facts) do | ctx|
          ctx.with_catalog_compiler do |c|
            c.evaluate(c.parse_string('define foo() { notify {nope: }} foo { test: }'))
            c.compile_additions
            c.with_json_encoding() {|encoder| encoder.encode }
          end
        end
        parsed = JSON.parse(result)
        expect(parsed['resources']).to include(include('type' => 'Notify'))
      end

      it 'an "evaluate" followed by "compile_additions" validates the result' do
        expect do
          Puppet::Pal.in_tmp_environment('pal_env', modulepath: modulepath, facts: node_facts) do | ctx|
            ctx.with_catalog_compiler do |c|
              c.evaluate(c.parse_string('define foo() { notify {nope: }} foo { test: before =>"Bar[nope]"}'))
              c.compile_additions
            end
          end
        end.to raise_error(Puppet::Error, /Could not find resource 'Bar\[nope\]'/)
      end

      it 'an "evaluate" followed by "evaluate_additions" does not validate the result' do
        result = Puppet::Pal.in_tmp_environment('pal_env', modulepath: modulepath, facts: node_facts) do | ctx|
          ctx.with_catalog_compiler do |c|
            c.evaluate(c.parse_string('define foo() { notify {nope: }} foo { test: before =>"Bar[nope]"}'))
            c.evaluate_additions
            c.with_json_encoding() {|encoder| encoder.encode }
          end
        end
        parsed = JSON.parse(result)
        expect(parsed['resources']).to include(include('type' => 'Notify'))
      end

      it 'an "evaluate" followed by "evaluate_additions" and "validate" validates the result' do
        expect do
          Puppet::Pal.in_tmp_environment('pal_env', modulepath: modulepath, facts: node_facts) do | ctx|
            ctx.with_catalog_compiler do |c|
              c.evaluate(c.parse_string('define foo() { notify {nope: }} foo { test: before =>"Bar[nope]"}'))
              c.compile_additions
              c.validate
            end
          end
        end.to raise_error(Puppet::Error, /Could not find resource 'Bar\[nope\]'/)
      end

      it 'an "evaluate" followed by "evaluate_ast_node" will correctly parse a node definition' do
        Puppet[:node_name_value] = 'testing_node'
        result = Puppet::Pal.in_tmp_environment('pal_env', modulepath: modulepath, facts: node_facts) do | ctx|
          ctx.with_catalog_compiler do |c|
            c.evaluate(c.parse_string("node 'testing_node' { notify {'PASSED': } }"))
            c.evaluate_ast_node
            c.compile_additions
            c.with_json_encoding() {|encoder| encoder.encode }
          end
        end
        parsed = JSON.parse(result)
        expect(parsed['resources']).to include(include('type' => 'Notify'))
      end
    end
  end

  context 'with code in modules and env' do
    let(:modulepath) { [modules_dir] }

    let(:metadata_json_a) {
      {
        'name' => 'example/a',
        'version' => '0.1.0',
        'source' => 'git@github.com/example/example-a.git',
        'dependencies' => [{'name' => 'c', 'version_range' => '>=0.1.0'}],
        'author' => 'Bob the Builder',
        'license' => 'Apache-2.0'
      }
    }

    let(:metadata_json_b) {
      {
        'name' => 'example/b',
        'version' => '0.1.0',
        'source' => 'git@github.com/example/example-b.git',
        'dependencies' => [{'name' => 'c', 'version_range' => '>=0.1.0'}],
        'author' => 'Bob the Builder',
        'license' => 'Apache-2.0'
      }
    }

    let(:metadata_json_c) {
      {
        'name' => 'example/c',
        'version' => '0.1.0',
        'source' => 'git@github.com/example/example-c.git',
        'dependencies' => [],
        'author' => 'Bob the Builder',
        'license' => 'Apache-2.0'
      }
    }

    # TODO: there is something amiss with the metadata wrt dependencies - when metadata is present there is an error
    #       that dependencies could not be resolved. Metadata is therefore commented out.
    #       Dependency based visibility is probably something that we should remove...
    let(:modules) {
      {
        'a' => {
        'functions' => a_functions,
        'lib' => { 'puppet' => a_lib_puppet },
        'types' => a_types,
        },
        'b' => {
        'functions' => b_functions,
        'lib' => b_lib,
        'types' => b_types,
        },
        'c' => {
        'types' => c_types,
        },
      }
    }

    let(:a_types) {
      {
        'atype.pp' => <<-PUPPET.unindent,
        type A::Atype = Integer
        PUPPET
      }
    }

    let(:a_functions) {
      {
        'afunc.pp' => 'function a::afunc() { "a::afunc value" }',
      }
    }

    let(:a_lib_puppet) {
      {
        'functions' => {
          'a' => {
            'arubyfunc.rb' => <<-RUBY.unindent,
              require 'stuff/something'
              Puppet::Functions.create_function(:'a::arubyfunc') do
                def arubyfunc
                  Stuff::SOMETHING
                end
              end
              RUBY
            'mycatalogcompilerfunc.rb' => <<-RUBY.unindent,
              Puppet::Functions.create_function(:'a::mycatalogcompilerfunc', Puppet::Functions::InternalFunction) do
                dispatch :mycatalogcompilerfunc do
                  compiler_param
                  param 'String',:name
                end

                def mycatalogcompilerfunc(the_compiler, name)
                  the_compiler.is_a?(Puppet::Pal::CatalogCompiler) ? name : 'no go'
                end
              end
              RUBY
          }
        },
        'datatypes' => {
          'mytype.rb' => <<-RUBY.unindent,
            Puppet::DataTypes.create_type('Mytype') do
              interface <<-PUPPET
                attributes => {
                  name => { type => String },
                  year_of_birth => { type => Integer },
                  age => { type => Integer, kind => derived },
                }
                PUPPET

              implementation do
                def age
                  DateTime.now.year - @year_of_birth
                end
              end
            end
            RUBY
        }
      }
    }

    let(:b_types) {
      {
        'atype.pp' => <<-PUPPET.unindent,
        type B::Atype = Integer
        PUPPET
      }
    }

    let(:b_functions) {
      {
        'afunc.pp' => 'function b::afunc() {}',
      }
    }

    let(:b_lib) {
      {
        'puppet' => b_lib_puppet,
        'stuff' => {
          'something.rb' => "module Stuff; SOMETHING = 'something'; end"
        }
      }
    }

    let(:b_lib_puppet) {
      {
        'functions' => {
        'b' => {
        'arubyfunc.rb' => "Puppet::Functions.create_function(:'b::arubyfunc') { def arubyfunc; 'arubyfunc_value'; end }",
        }
        }
      }
    }

    let(:c_types) {
      {
        'atype.pp' => <<-PUPPET.unindent,
        type C::Atype = Integer
        PUPPET
      }
    }

    context 'configured as temporary environment such that' do
      it 'modules are available' do
        result = Puppet::Pal.in_tmp_environment('pal_env', modulepath: modulepath, facts: node_facts) do |ctx|
          ctx.with_catalog_compiler {|c| c.evaluate_string('a::afunc()') }
        end
        expect(result).to eq("a::afunc value")
      end

      it 'libs in a given "modulepath" are added to the Ruby $LOAD_PATH' do
        result = Puppet::Pal.in_tmp_environment('pal_env', modulepath: modulepath, facts: node_facts) do |ctx|
          ctx.with_catalog_compiler {|c| c.evaluate_string('a::arubyfunc()') }
        end
        expect(result).to eql('something')
      end

      it 'errors if a block is not given to in_tmp_environment' do
        expect do
          Puppet::Pal.in_tmp_environment('pal_env', modulepath: modulepath, facts: node_facts)
        end.to raise_error(/A block must be given to 'in_tmp_environment/)
      end

      it 'errors if an env_name is given and is not a String[1]' do
        expect do
          Puppet::Pal.in_tmp_environment('', modulepath: modulepath, facts: node_facts) { |ctx| }
        end.to raise_error(/temporary environment name has wrong type/)

        expect do
          Puppet::Pal.in_tmp_environment(32, modulepath: modulepath, facts: node_facts) { |ctx| }
        end.to raise_error(/temporary environment name has wrong type/)
      end

      { 'a hash'                => {'a' => 'hm'},
        'an integer'            => 32,
        'separated strings'     => 'dir1;dir2',
        'empty string in array' => ['']
      }.each_pair do |what, value|
        it "errors if modulepath is #{what}" do
          expect do
            Puppet::Pal.in_tmp_environment('pal_env', modulepath: value, facts: node_facts) { |ctx| }
          end.to raise_error(/modulepath has wrong type/)
        end
      end

      context 'facts are supported such that' do
        it 'they are obtained if they are not given' do
          facts = Puppet::Node::Facts.new(Puppet[:certname], 'puppetversion' => Puppet.version)
          Puppet::Node::Facts.indirection.save(facts)

          testing_env_dir # creates the structure
          result = Puppet::Pal.in_tmp_environment('pal_env', modulepath: modulepath ) do |ctx|
            ctx.with_catalog_compiler {|c| c.evaluate_string("$facts =~ Hash and $facts[puppetversion] == '#{Puppet.version}'") }
          end
          expect(result).to eq(true)
        end

        it 'can be given as a hash when creating the environment' do
          testing_env_dir # creates the structure
          result = Puppet::Pal.in_tmp_environment('pal_env', modulepath: modulepath, facts: { 'myfact' => 42 }) do |ctx|
            ctx.with_catalog_compiler {|c| c.evaluate_string("$facts =~ Hash and $facts[myfact] == 42") }
          end
          expect(result).to eq(true)
        end

        it 'can be overridden with a hash when creating a script compiler' do
          testing_env_dir # creates the structure
          result = Puppet::Pal.in_tmp_environment('pal_env', modulepath: modulepath, facts: { 'myfact' => 42 }) do |ctx|
            ctx.with_catalog_compiler(facts: { 'myfact' => 43 }) {|c| c.evaluate_string("$facts =~ Hash and $facts[myfact] == 43") }
          end
          expect(result).to eq(true)
        end
      end

      context 'datatypes are supported such that' do
        it 'datatypes defined as pcore in a module are deserialized' do
          testing_env_dir
          vars = {"bobs_age"=>{"__ptype"=>"Mytype", "name"=>"Bob", "year_of_birth"=>1984}}
          result = Puppet::Pal.in_environment('pal_env', envpath: environments_dir, facts: node_facts, variables: vars) do |ctx|
            ctx.with_catalog_compiler {|c| c.evaluate_string("$bobs_age.age") }
          end
          expect(result).to eq(DateTime.now.year - 1984)
        end
      end

      context 'configured as an existing given environment directory such that' do
        it 'modules in it are available from its "modules" directory' do
          result = Puppet::Pal.in_environment('pal_env', env_dir: testing_env_dir, facts: node_facts) do |ctx|
            ctx.with_catalog_compiler {|c| c.evaluate_string('a::afunc()') }
          end
          expect(result).to eq("a::afunc value")
        end

        it 'libs in a given "modulepath" are added to the Ruby $LOAD_PATH' do
          result = Puppet::Pal.in_environment('pal_env', env_dir: testing_env_dir, facts: node_facts) do |ctx|
            ctx.with_catalog_compiler {|c| c.evaluate_string('a::arubyfunc()') }
          end
          expect(result).to eql('something')
        end

        it 'a given "modulepath" overrides the default' do
          expect do
            Puppet::Pal.in_environment('pal_env', env_dir: testing_env_dir, modulepath: [], facts: node_facts) do |ctx|
              ctx.with_catalog_compiler {|c| c.evaluate_string('a::afunc()') }
            end
          end.to raise_error(/Unknown function: 'a::afunc'/)
        end

        it 'a "pre_modulepath" is prepended and a "post_modulepath" is appended to the effective modulepath' do
          other_modules1 = File.join(environments_dir, 'other_env1/modules')
          other_modules2 = File.join(environments_dir, 'other_env2/modules')
          result = Puppet::Pal.in_environment('pal_env', env_dir: testing_env_dir,
            pre_modulepath: [other_modules1],
            post_modulepath: [other_modules2],
            facts: node_facts
          ) do |ctx|
            the_modulepath = Puppet.lookup(:environments).get('pal_env').modulepath
            the_modulepath[0] == other_modules1 && the_modulepath[-1] == other_modules2
          end
          expect(result).to be(true)
        end

        it 'can set variables in any scope' do
          vars = {'a'=> 10, 'x::y' => 20}
          result = Puppet::Pal.in_environment('pal_env', env_dir: testing_env_dir, facts: node_facts, variables: vars) do |ctx|
            ctx.with_catalog_compiler { |c| c.evaluate_string("1+2+3+4+$a+$x::y") }
          end
          expect(result).to eq(40)
        end

        it 'errors in a meaningful way when a non existing env name is given' do
          testing_env_dir # creates the structure
          expect do
            Puppet::Pal.in_environment('blah_env', env_dir: testing_env_dir.chop, facts: node_facts) { |ctx| }
          end.to raise_error(/The environment directory '.*' does not exist/)
        end

        it 'errors if an env_name is given and is not a String[1]' do
          expect do
            Puppet::Pal.in_environment('', env_dir: testing_env_dir, facts: node_facts)  { |ctx| }
          end.to raise_error(/env_name has wrong type/)

          expect do
            Puppet::Pal.in_environment(32, env_dir: testing_env_dir, facts: node_facts)  { |ctx| }
          end.to raise_error(/env_name has wrong type/)
        end
      end
    end

    context 'configured as existing given envpath such that' do
      it 'modules in it are available from its "modules" directory' do
        testing_env_dir # creates the structure
        result = Puppet::Pal.in_environment('pal_env', envpath: environments_dir, facts: node_facts) do |ctx|
          ctx.with_catalog_compiler { |c| c.evaluate_string('a::afunc()') }
        end
        expect(result).to eq("a::afunc value")
      end

      it 'a given "modulepath" overrides the default' do
        testing_env_dir # creates the structure
        expect do
          Puppet::Pal.in_environment('pal_env', envpath: environments_dir, modulepath: [], facts: node_facts) do |ctx|
            ctx.with_catalog_compiler { |c| c.evaluate_string('a::afunc()') }
          end
        end.to raise_error(/Unknown function: 'a::afunc'/)
      end

      it 'the envpath can have multiple entries - that are searched for the given env' do
        testing_env_dir # creates the structure
        result = Puppet::Pal.in_environment('pal_env', envpath: environments_dir, facts: node_facts) do |ctx|
          ctx.with_catalog_compiler {|c| c.evaluate_string('a::afunc()') }
        end
        expect(result).to eq("a::afunc value")
      end

      context 'with a catalog compiler' do
        it 'uses configured manifest_file if configured_by_env is true and Puppet[:code] is unset' do
          testing_env_dir # creates the structure
          Puppet[:manifest] = file_containing('afunc.pp', "function myfunc(Integer $a) { $a * 2 } ")
          result = Puppet::Pal.in_environment('pal_env', envpath: environments_dir, facts: node_facts) do |ctx|
            ctx.with_catalog_compiler(configured_by_env: true) {|c|  c.call_function('myfunc', 4)}
          end
          expect(result).to eql(8)
        end

        it 'uses Puppet[:code] if configured_by_env is true and Puppet[:code] is set' do
          testing_env_dir # creates the structure
          Puppet[:manifest] = file_containing('amanifest.pp', "$a = 20")
          Puppet[:code] = '$a = 40'
          result = Puppet::Pal.in_environment('pal_env', envpath: environments_dir, facts: node_facts) do |ctx|
            ctx.with_catalog_compiler(configured_by_env: true) {|c|  c.evaluate_string('$a')}
          end
          expect(result).to eql(40)
        end

        it 'makes the pal CatalogCompiler available as catalog_compiler_param to Function dispatcher' do
          testing_env_dir # creates the structure
          Puppet[:manifest] = file_containing('noop.pp', "undef")
          result = Puppet::Pal.in_environment('pal_env', envpath: environments_dir, facts: node_facts) do |ctx|
            ctx.with_catalog_compiler(configured_by_env: true) {|c|  c.call_function('a::mycatalogcompilerfunc', 'go')}
          end
          expect(result).to eql('go')
        end
      end
    end
  end
end

