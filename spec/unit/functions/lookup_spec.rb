#! /usr/bin/env ruby
require 'spec_helper'
require 'puppet_spec/compiler'
require 'puppet/pops'

describe "when performing lookup" do
  include PuppetSpec::Compiler

  # Assembles code that includes the *abc* class and compiles it into a catalog. This class will use the global
  # variable $args to perform a lookup and assign the result to $abc::result. The assembled code will declare
  # a notify resource with a name that is formed by interpolating the result into a format string.
  #
  # The method performs the folloging steps.
  #
  # - Build the code that:
  #    - sets the $args variable from _lookup_args_
  #    - includes the abc class
  #    - assigns the $abc::result to $r
  #    - interpolates a string using _fmt_ (which is assumed to use $r)
  #    - declares a notify resource from the interpolated string
  # - Compile the code into a catalog
  # - Return the name of all Notify resources in that catalog
  #
  # @param fmt [String] The puppet interpolated string used when creating the notify name
  # @param *args [String] splat of args that will be concatenated to form the puppet args sent to lookup
  # @return [Array<String>] List of names of Notify resources in the resulting catalog
  #
  def assemble_and_compile(fmt, *lookup_args)
    Puppet[:code] = \
      "$args = [#{lookup_args.join(',')}]\n"\
      "include abc\n"\
      "$r = if $abc::result == undef { 'no_value' } else { $abc::result }\n"\
      "notify { \"#{fmt}\": }\n"
    compiler.compile().resources.map(&:ref).select { |r| r.start_with?('Notify[') }.map { |r| r[7..-2] }
  end

  def assemble_and_compile_with_block(fmt, block, *lookup_args)
    Puppet[:code] = "$args = [#{lookup_args.join(',')}]\n$block = #{block}\ninclude abc\n$r = $abc::result\nnotify { \"#{fmt}\": }\n"
    compiler.compile().resources.map(&:ref).select { |r| r.start_with?('Notify[') }.map { |r| r[7..-2] }
  end

  # There is a fully configured 'production' environment in fixtures at this location
  let(:environmentpath) { File.join(my_fixture_dir, 'environments') }
  let(:node) { Puppet::Node.new("testnode", :facts => Puppet::Node::Facts.new("facts", {}), :environment => 'production') }
  let(:compiler) { Puppet::Parser::Compiler.new(node) }

  around(:each) do |example|
    # Initialize settings to get a full compile as close as possible to a real
    # environment load
    Puppet.settings.initialize_global_settings

    # Initialize loaders based on the environmentpath. It does not work to
    # just set the setting environmentpath for some reason - this achieves the same:
    # - first a loader is created, loading directory environments from the fixture (there is
    # one environment, 'sample', which will be loaded since the node references this
    # environment by name).
    # - secondly, the created env loader is set as 'environments' in the puppet context.
    #
    environments = Puppet::Environments::Directories.new(environmentpath, [])
    Puppet.override(:environments => environments) do
      example.run
    end
  end

  context 'using normal parameters' do
    it 'can lookup value provided by the environment' do
      resources = assemble_and_compile('${r}', "'a'")
      expect(resources).to include('env_a')
    end

    it 'can lookup value provided by the module' do
      resources = assemble_and_compile('${r}', "'b'")
      expect(resources).to include('module_b')
    end

    it 'can lookup value provided in global scope' do
      Hiera.any_instance.expects(:lookup).with('a', any_parameters).returns('global_a')
      resources = assemble_and_compile('${r}', "'a'")
      expect(resources).to include('global_a')
    end

    it 'will stop at first found name when several names are provided' do
      resources = assemble_and_compile('${r}', "['b', 'a']")
      expect(resources).to include('module_b')
    end

    it 'can lookup value provided by the module' do
      resources = assemble_and_compile('${r}', "'b'")
      expect(resources).to include('module_b')
    end

    it 'can lookup value provided by the module that is overriden by environment' do
      resources = assemble_and_compile('${r}', "'c'")
      expect(resources).to include('env_c')
    end

    it "can 'unique' merge values provided by both the module and the environment" do
      resources = assemble_and_compile('${r[0]}_${r[1]}', "'c'", 'Array[String]', 'undef', "'unique'")
      expect(resources).to include('env_c_module_c')
    end

    it "can 'hash' merge values provided by the environment only" do
      resources = assemble_and_compile('${r[k1]}_${r[k2]}_${r[k3]}', "'d'", 'Hash[String,String]', 'undef', "'hash'")
      expect(resources).to include('env_d1_env_d2_env_d3')
    end

    it "can 'hash' merge values provided by both the environment and the module" do
      resources = assemble_and_compile('${r[k1]}_${r[k2]}_${r[k3]}', "'e'", 'Hash[String,String]', 'undef', "'hash'")
      expect(resources).to include('env_e1_module_e2_env_e3')
    end

    it "can 'hash' merge values provided by global, environment, and module" do
      Hiera.any_instance.expects(:lookup).with('e', any_parameters).returns({ 'k1' => 'global_e1' })
      resources = assemble_and_compile('${r[k1]}_${r[k2]}_${r[k3]}', "'e'", 'Hash[String,String]', 'undef', "'hash'")
      expect(resources).to include('global_e1_module_e2_env_e3')
    end

    it "can pass merge parameter in the form of a hash with a 'strategy'" do
      resources = assemble_and_compile('${r[k1]}_${r[k2]}_${r[k3]}', "'e'", 'Hash[String,String]', 'undef', "{strategy => 'hash'}")
      expect(resources).to include('env_e1_module_e2_env_e3')
    end

    it "will fail unless merge in the form of a hash contains a 'strategy'" do
      expect do
        assemble_and_compile('${r[k1]}_${r[k2]}_${r[k3]}', "'e'", 'Hash[String,String]', 'undef', "{merge_key => 'hash'}")
      end.to raise_error(Puppet::ParseError, /'merge' parameter must contain a 'strategy'/)
    end

    it 'will raise an exception when value is not found for single key and no default is provided' do
      expect do
        assemble_and_compile('${r}', "'x'")
      end.to raise_error(Puppet::ParseError, /did not find a value for the name 'x'/)
    end

    it 'will raise an exception when value is not found for array key and no default is provided' do
      expect do
        assemble_and_compile('${r}', "['x', 'y']")
      end.to raise_error(Puppet::ParseError, /did not find a value for any of the names \['x', 'y'\]/)
    end

    if Puppet::Pops::MergeStrategy.strategy_keys.include?(:deep)
      it 'can lookup and deep merge shallow values provided by the environment only' do
        resources = assemble_and_compile('${r[k1]}_${r[k2]}_${r[k3]}', "'d'", 'Hash[String,String]', 'undef', "'deep'")
        expect(resources).to include('env_d1_env_d2_env_d3')
      end

      it 'can lookup and deep merge shallow values provided by both the module and the environment' do
        resources = assemble_and_compile('${r[k1]}_${r[k2]}_${r[k3]}', "'e'", 'Hash[String,String]', 'undef', "'deep'")
        expect(resources).to include('env_e1_module_e2_env_e3')
      end

      it 'can lookup and deep merge deep values provided by global, environment, and module' do
        Hiera.any_instance.expects(:lookup).with('f', any_parameters).returns({ 'k1' => { 's1' => 'global_f11' }, 'k2' => { 's3' => 'global_f23' }})
        resources = assemble_and_compile('${r[k1][s1]}_${r[k1][s2]}_${r[k1][s3]}_${r[k2][s1]}_${r[k2][s2]}_${r[k2][s3]}', "'f'", 'Hash[String,Hash[String,String]]', 'undef', "'deep'")
        expect(resources).to include('global_f11_env_f12_module_f13_env_f21_module_f22_global_f23')
      end
    end

    context 'with provided default' do
      it 'will return default when lookup fails' do
        resources = assemble_and_compile('${r}', "'x'", 'String', "'dflt_x'")
        expect(resources).to include('dflt_x')
      end

      it 'can precede default_value parameter with undef as the value_type' do
        resources = assemble_and_compile('${r}', "'x'", 'undef', "'dflt_x'")
        expect(resources).to include('dflt_x')
      end

      it 'can use array' do
        resources = assemble_and_compile('${r[0]}_${r[1]}', "'x'", 'Array[String]', "['dflt_x', 'dflt_y']")
        expect(resources).to include('dflt_x_dflt_y')
      end

      it 'can use hash' do
        resources = assemble_and_compile('${r[a]}_${r[b]}', "'x'", 'Hash[String,String]', "{'a' => 'dflt_x', 'b' => 'dflt_y'}")
        expect(resources).to include('dflt_x_dflt_y')
      end

      it 'fails unless default is an instance of value_type' do
        expect do
          assemble_and_compile('${r[a]}_${r[b]}', "'x'", 'Hash[String,String]', "{'a' => 'dflt_x', 'b' => 32}")
        end.to raise_error(Puppet::ParseError, /default_value value has wrong type/)
      end
    end

    context 'with a default block' do
      it 'will be called when lookup fails' do
        resources = assemble_and_compile_with_block('${r}', "'dflt_x'", "'x'")
        expect(resources).to include('dflt_x')
      end

      it 'can use array' do
        resources = assemble_and_compile_with_block('${r[0]}_${r[1]}', "['dflt_x', 'dflt_y']", "'x'")
        expect(resources).to include('dflt_x_dflt_y')
      end

      it 'can use hash' do
        resources = assemble_and_compile_with_block('${r[a]}_${r[b]}', "{'a' => 'dflt_x', 'b' => 'dflt_y'}", "'x'")
        expect(resources).to include('dflt_x_dflt_y')
      end

      it 'fails unless block returns an instance of value_type' do
        expect do
          assemble_and_compile_with_block('${r[a]}_${r[b]}', "{'a' => 'dflt_x', 'b' => 32}", "'x'", 'Hash[String,String]')
        end.to raise_error(Puppet::ParseError, /default_block value has wrong type/)
      end

      it 'receives a single name parameter' do
        resources = assemble_and_compile_with_block('${r}', 'true', "'name_x'")
        expect(resources).to include('name_x')
      end

      it 'receives an array name parameter' do
        resources = assemble_and_compile_with_block('${r[0]}_${r[1]}', 'true', "['name_x', 'name_y']")
        expect(resources).to include('name_x_name_y')
      end
    end
  end

  context 'when passing a hash as the only parameter' do
    it 'can pass a single name correctly' do
      resources = assemble_and_compile('${r}', "{name => 'a'}")
      expect(resources).to include('env_a')
    end

    it 'can pass a an array of names correctly' do
      resources = assemble_and_compile('${r}', "{name => ['b', 'a']}")
      expect(resources).to include('module_b')
    end

    it 'can pass an override map and find values there even though they would be found' do
      resources = assemble_and_compile('${r}', "{name => 'a', override => { a => 'override_a'}}")
      expect(resources).to include('override_a')
    end

    it 'can pass an extra map and find values there correctly' do
      resources = assemble_and_compile('${r}', "{name => 'x', extra => { x => 'extra_x'}}")
      expect(resources).to include('extra_x')
    end

    it 'can pass an extra map but not use it when value is found elsewhere' do
      resources = assemble_and_compile('${r}', "{name => 'a', extra => { a => 'extra_a'}}")
      expect(resources).to include('env_a')
    end

    it 'can pass an override and an extra map and find the override value' do
      resources = assemble_and_compile('${r}', "{name => 'x', override => { x => 'override_x'}, extra => { x => 'extra_x'}}")
      expect(resources).to include('override_x')
    end

    it 'will raise an exception when value is not found for single key and no default is provided' do
      expect do
        assemble_and_compile('${r}', "{name => 'x'}")
      end.to raise_error(Puppet::ParseError, /did not find a value for the name 'x'/)
    end

    it 'will not raise an exception when value is not found and accept_undef is true' do
      resources = assemble_and_compile('${r}', "{name => 'x', accept_undef => true}")
      expect(resources).to include('no_value')
    end
  end
end
