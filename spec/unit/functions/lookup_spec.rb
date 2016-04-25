#! /usr/bin/env ruby
require 'spec_helper'
require 'puppet_spec/compiler'
require 'puppet/pops'

describe "when performing lookup" do
  include PuppetSpec::Compiler

  # Assembles code that includes the *abc* class and compiles it into a catalog. This class will use the global
  # variable $args to perform a lookup and assign the result to $abc::result. Unless the $block is set to
  # the string 'no_block_present', it will be passed as a lambda to the lookup. The assembled code will declare
  # a notify resource with a name that is formed by interpolating the result into a format string.
  #
  # The method performs the folloging steps.
  #
  # - Build the code that:
  #    - sets the $args variable from _lookup_args_
  #    - sets the $block parameter to the given block or the string 'no_block_present'
  #    - includes the abc class
  #    - assigns the $abc::result to $r
  #    - interpolates a string using _fmt_ (which is assumed to use $r)
  #    - declares a notify resource from the interpolated string
  # - Compile the code into a catalog
  # - Return the name of all Notify resources in that catalog
  #
  # @param fmt [String] The puppet interpolated string used when creating the notify title
  # @param *args [String] splat of args that will be concatenated to form the puppet args sent to lookup
  # @return [Array<String>] List of names of Notify resources in the resulting catalog
  #
  def assemble_and_compile(fmt, *lookup_args, &block)
    assemble_and_compile_with_block(fmt, "'no_block_present'", *lookup_args, &block)
  end

  def assemble_and_compile_with_block(fmt, block, *lookup_args, &cblock)
    compile_and_get_notifications(<<-END.gsub(/^ {6}/, ''), &cblock)
      $args = [#{lookup_args.join(',')}]
      $block = #{block}
      include abc
      $r = if $abc::result == undef { 'no_value' } else { $abc::result }
      notify { \"#{fmt}\": }
    END
  end

  def compile_and_get_notifications(code)
    Puppet[:code] = code
    catalog = block_given? ? compiler.compile { |catalog| yield(compiler.topscope); catalog } : compiler.compile
    catalog.resources.map(&:ref).select { |r| r.start_with?('Notify[') }.map { |r| r[7..-2] }
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
      resources = assemble_and_compile('${r}', "'abc::a'")
      expect(resources).to include('env_a')
    end

    it 'can lookup value provided by the module' do
      resources = assemble_and_compile('${r}', "'abc::b'")
      expect(resources).to include('module_b')
    end

    it "can lookup value provided by the module that has 'function' data_provider entry in metadata.json" do
      resources = compile_and_get_notifications("$args = ['meta::b']\ninclude meta\nnotify { $meta::result: }\n")
      expect(resources).to include('module_b')
    end

    it "can lookup value provided by the module that has 'sample' data_provider entry in metadata.json" do
      resources = compile_and_get_notifications("$args = ['metawcp::b']\ninclude metawcp\nnotify { $metawcp::result: }\n")
      expect(resources).to include('module_b')
    end

    it 'can lookup value provided in global scope' do
      Hiera.any_instance.expects(:lookup).with('lookup_options', any_parameters).at_most_once.throws(:no_such_key)
      Hiera.any_instance.expects(:lookup).with('abc::a', any_parameters).returns('global_a')
      resources = assemble_and_compile('${r}', "'abc::a'")
      expect(resources).to include('global_a')
    end

    it 'will stop at first found name when several names are provided' do
      resources = assemble_and_compile('${r}', "['abc::b', 'abc::a']")
      expect(resources).to include('module_b')
    end

    it 'can lookup value provided by the module that is overriden by environment' do
      resources = assemble_and_compile('${r}', "'abc::c'")
      expect(resources).to include('env_c')
    end

    it "can 'unique' merge values provided by both the module and the environment" do
      resources = assemble_and_compile('${r[0]}_${r[1]}', "'abc::c'", 'Array[String]', "'unique'")
      expect(resources).to include('env_c_module_c')
    end

    it "can 'hash' merge values provided by the environment only" do
      resources = assemble_and_compile('${r[k1]}_${r[k2]}_${r[k3]}', "'abc::d'", 'Hash[String,String]', "'hash'")
      expect(resources).to include('env_d1_env_d2_env_d3')
    end

    it "can 'hash' merge values provided by both the environment and the module" do
      resources = assemble_and_compile('${r[k1]}_${r[k2]}_${r[k3]}', "'abc::e'", 'Hash[String,String]', "'hash'")
      expect(resources).to include('env_e1_module_e2_env_e3')
    end

    it "can 'hash' merge values provided by global, environment, and module" do
      Hiera.any_instance.expects(:lookup).with('lookup_options', any_parameters).at_most_once.throws(:no_such_key)
      Hiera.any_instance.expects(:lookup).with('abc::e', any_parameters).returns({ 'k1' => 'global_e1' })
      resources = assemble_and_compile('${r[k1]}_${r[k2]}_${r[k3]}', "'abc::e'", 'Hash[String,String]', "'hash'")
      expect(resources).to include('global_e1_module_e2_env_e3')
    end

    it "can pass merge parameter in the form of a hash with a 'strategy=>unique'" do
      resources = assemble_and_compile('${r[0]}_${r[1]}', "'abc::c'", 'Array[String]', "{strategy => 'unique'}")
      expect(resources).to include('env_c_module_c')
    end

    it "can pass merge parameter in the form of a hash with 'strategy=>hash'" do
      resources = assemble_and_compile('${r[k1]}_${r[k2]}_${r[k3]}', "'abc::e'", 'Hash[String,String]', "{strategy => 'hash'}")
      expect(resources).to include('env_e1_module_e2_env_e3')
    end

    it "can pass merge parameter in the form of a hash with a 'strategy=>deep'" do
      resources = assemble_and_compile('${r[k1]}_${r[k2]}_${r[k3]}', "'abc::e'", 'Hash[String,String]', "{strategy => 'deep'}")
      expect(resources).to include('env_e1_module_e2_env_e3')
    end

    it "will fail unless merge in the form of a hash contains a 'strategy'" do
      expect do
        assemble_and_compile('${r[k1]}_${r[k2]}_${r[k3]}', "'abc::e'", 'Hash[String,String]', "{merge_key => 'hash'}")
      end.to raise_error(Puppet::ParseError, /hash given as 'merge' must contain the name of a strategy/)
    end

    it 'will raise an exception when value is not found for single key and no default is provided' do
      expect do
        assemble_and_compile('${r}', "'abc::x'")
      end.to raise_error(Puppet::ParseError, /did not find a value for the name 'abc::x'/)
    end

    it 'can lookup an undef value' do
      resources = assemble_and_compile('${r}', "'abc::n'")
      expect(resources).to include('no_value')
    end

    it 'will not replace an undef value with a given default' do
      resources = assemble_and_compile('${r}', "'abc::n'", 'undef', 'undef', '"default_n"')
      expect(resources).to include('no_value')
    end

    it 'will not accept a succesful lookup of an undef value when the type rejects it' do
      expect do
        assemble_and_compile('${r}', "'abc::n'", 'String')
      end.to raise_error(Puppet::ParseError, /Found value had wrong type, expected a String value, got Undef/)
    end

    it 'will raise an exception when value is not found for array key and no default is provided' do
      expect do
        assemble_and_compile('${r}', "['abc::x', 'abc::y']")
      end.to raise_error(Puppet::ParseError, /did not find a value for any of the names \['abc::x', 'abc::y'\]/)
    end

    it 'can lookup and deep merge shallow values provided by the environment only' do
      resources = assemble_and_compile('${r[k1]}_${r[k2]}_${r[k3]}', "'abc::d'", 'Hash[String,String]', "'deep'")
      expect(resources).to include('env_d1_env_d2_env_d3')
    end

    it 'can lookup and deep merge shallow values provided by both the module and the environment' do
      resources = assemble_and_compile('${r[k1]}_${r[k2]}_${r[k3]}', "'abc::e'", 'Hash[String,String]', "'deep'")
      expect(resources).to include('env_e1_module_e2_env_e3')
    end

    it 'can lookup and deep merge deep values provided by global, environment, and module' do
      Hiera.any_instance.expects(:lookup).with('lookup_options', any_parameters).at_most_once.throws(:no_such_key)
      Hiera.any_instance.expects(:lookup).with('abc::f', any_parameters).returns({ 'k1' => { 's1' => 'global_f11' }, 'k2' => { 's3' => 'global_f23' }})
      resources = assemble_and_compile('${r[k1][s1]}_${r[k1][s2]}_${r[k1][s3]}_${r[k2][s1]}_${r[k2][s2]}_${r[k2][s3]}', "'abc::f'", 'Hash[String,Hash[String,String]]', "'deep'")
      expect(resources).to include('global_f11_env_f12_module_f13_env_f21_module_f22_global_f23')
    end

    it 'will propagate resolution_type :array to Hiera when merge == \'unique\''  do
      Hiera.any_instance.expects(:lookup).with('lookup_options', any_parameters).at_most_once.throws(:no_such_key)
      Hiera.any_instance.expects(:lookup).with('abc::c', anything, anything, anything, :array).returns(['global_c'])
      resources = assemble_and_compile('${r[0]}_${r[1]}_${r[2]}', "'abc::c'", 'Array[String]', "'unique'")
      expect(resources).to include('global_c_env_c_module_c')
    end

    it 'will propagate a Hash resolution_type with :behavior => :native to Hiera when merge == \'hash\''  do
      Hiera.any_instance.expects(:lookup).with('lookup_options', any_parameters).at_most_once.throws(:no_such_key)
      Hiera.any_instance.expects(:lookup).with('abc::e', anything, anything, anything, { :behavior => :native }).returns({ 'k1' => 'global_e1' })
      resources = assemble_and_compile('${r[k1]}_${r[k2]}_${r[k3]}', "'abc::e'", 'Hash[String,String]', "{strategy => 'hash'}")
      expect(resources).to include('global_e1_module_e2_env_e3')
    end

    it 'will propagate a Hash resolution_type with :behavior => :deeper to Hiera when merge == \'deep\''  do
      Hiera.any_instance.expects(:lookup).with('lookup_options', any_parameters).at_most_once.throws(:no_such_key)
      Hiera.any_instance.expects(:lookup).with('abc::f', anything, anything, anything, { :behavior => :deeper }).returns({ 'k1' => { 's1' => 'global_f11' }, 'k2' => { 's3' => 'global_f23' }})
      resources = assemble_and_compile('${r[k1][s1]}_${r[k1][s2]}_${r[k1][s3]}_${r[k2][s1]}_${r[k2][s2]}_${r[k2][s3]}', "'abc::f'", 'Hash[String,Hash[String,String]]', "'deep'")
      expect(resources).to include('global_f11_env_f12_module_f13_env_f21_module_f22_global_f23')
    end

    it 'will propagate a Hash resolution_type with symbolic deep merge options to Hiera'  do
      Hiera.any_instance.expects(:lookup).with('lookup_options', any_parameters).at_most_once.throws(:no_such_key)
      Hiera.any_instance.expects(:lookup).with('abc::f', anything, anything, anything, { :behavior => :deeper, :knockout_prefix => '--' }).returns({ 'k1' => { 's1' => 'global_f11' }, 'k2' => { 's3' => 'global_f23' }})
      resources = assemble_and_compile('${r[k1][s1]}_${r[k1][s2]}_${r[k1][s3]}_${r[k2][s1]}_${r[k2][s2]}_${r[k2][s3]}', "'abc::f'", 'Hash[String,Hash[String,String]]', "{ 'strategy' => 'deep', 'knockout_prefix' => '--' }")
      expect(resources).to include('global_f11_env_f12_module_f13_env_f21_module_f22_global_f23')
    end

    context 'with provided default' do
      it 'will return default when lookup fails' do
        resources = assemble_and_compile('${r}', "'abc::x'", 'String', 'undef', "'dflt_x'")
        expect(resources).to include('dflt_x')
      end

      it 'can precede default parameter with undef as the value_type and undef as the merge type' do
        resources = assemble_and_compile('${r}', "'abc::x'", 'undef', 'undef', "'dflt_x'")
        expect(resources).to include('dflt_x')
      end

      it 'can use array' do
        resources = assemble_and_compile('${r[0]}_${r[1]}', "'abc::x'", 'Array[String]', 'undef', "['dflt_x', 'dflt_y']")
        expect(resources).to include('dflt_x_dflt_y')
      end

      it 'can use hash' do
        resources = assemble_and_compile('${r[a]}_${r[b]}', "'abc::x'", 'Hash[String,String]', 'undef', "{'a' => 'dflt_x', 'b' => 'dflt_y'}")
        expect(resources).to include('dflt_x_dflt_y')
      end

      it 'fails unless default is an instance of value_type' do
        expect do
          assemble_and_compile('${r[a]}_${r[b]}', "'abc::x'", 'Hash[String,String]', 'undef', "{'a' => 'dflt_x', 'b' => 32}")
        end.to raise_error(Puppet::ParseError,
          /Default value had wrong type, entry 'b' expected a String value, got Integer/)
      end
    end

    context 'with a default block' do
      it 'will be called when lookup fails' do
        resources = assemble_and_compile_with_block('${r}', "'dflt_x'", "'abc::x'")
        expect(resources).to include('dflt_x')
      end

      it 'will not called when lookup succeeds but the found value is nil' do
        resources = assemble_and_compile_with_block('${r}', "'dflt_x'", "'abc::n'")
        expect(resources).to include('no_value')
      end

      it 'can use array' do
        resources = assemble_and_compile_with_block('${r[0]}_${r[1]}', "['dflt_x', 'dflt_y']", "'abc::x'")
        expect(resources).to include('dflt_x_dflt_y')
      end

      it 'can use hash' do
        resources = assemble_and_compile_with_block('${r[a]}_${r[b]}', "{'a' => 'dflt_x', 'b' => 'dflt_y'}", "'abc::x'")
        expect(resources).to include('dflt_x_dflt_y')
      end

      it 'can return undef from block' do
        resources = assemble_and_compile_with_block('${r}', 'undef', "'abc::x'")
        expect(resources).to include('no_value')
      end

      it 'fails unless block returns an instance of value_type' do
        expect do
          assemble_and_compile_with_block('${r[a]}_${r[b]}', "{'a' => 'dflt_x', 'b' => 32}", "'abc::x'", 'Hash[String,String]')
        end.to raise_error(Puppet::ParseError,
          /Value returned from default block had wrong type, entry 'b' expected a String value, got Integer/)
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

  context 'when using dotted keys' do
    it 'can access values in data using dot notation' do
      source = <<-CODE
      function environment::data() {
        { a => { b => { c => 'the data' }}}
      }
      notice(lookup('a.b.c'))
      CODE
      expect(eval_and_collect_notices(source)).to include('the data')
    end

    it 'can find data using quoted dot notation' do
      source = <<-CODE
      function environment::data() {
        { 'a.b.c' => 'the data' }
      }
      notice(lookup('"a.b.c"'))
      CODE
      expect(eval_and_collect_notices(source)).to include('the data')
    end

    it 'can access values in data using a mix of dot notation and quoted dot notation' do
      source = <<-CODE
      function environment::data() {
        { 'a' => { 'b.c' => 'the data' }}
      }
      notice(lookup('a."b.c"'))
      CODE
      expect(eval_and_collect_notices(source)).to include('the data')
    end
  end

  context 'when passing a hash as the only parameter' do
    it 'can pass a single name correctly' do
      resources = assemble_and_compile('${r}', "{name => 'abc::a'}")
      expect(resources).to include('env_a')
    end

    it 'can pass a an array of names correctly' do
      resources = assemble_and_compile('${r}', "{name => ['abc::b', 'abc::a']}")
      expect(resources).to include('module_b')
    end

    it 'can pass an override map and find values there even though they would be found' do
      resources = assemble_and_compile('${r}', "{name => 'abc::a', override => { abc::a => 'override_a'}}")
      expect(resources).to include('override_a')
    end

    it 'can pass an default_values_hash and find values there correctly' do
      resources = assemble_and_compile('${r}', "{name => 'abc::x', default_values_hash => { abc::x => 'extra_x'}}")
      expect(resources).to include('extra_x')
    end

    it 'can pass an default_values_hash but not use it when value is found elsewhere' do
      resources = assemble_and_compile('${r}', "{name => 'abc::a', default_values_hash => { abc::a => 'extra_a'}}")
      expect(resources).to include('env_a')
    end

    it 'can pass an default_values_hash but not use it when value is found elsewhere even when found value is undef' do
      resources = assemble_and_compile('${r}', "{name => 'abc::n', default_values_hash => { abc::n => 'extra_n'}}")
      expect(resources).to include('no_value')
    end

    it 'can pass an override and an default_values_hash and find the override value' do
      resources = assemble_and_compile('${r}', "{name => 'abc::x', override => { abc::x => 'override_x'}, default_values_hash => { abc::x => 'extra_x'}}")
      expect(resources).to include('override_x')
    end

    it 'will raise an exception when value is not found for single key and no default is provided' do
      expect do
        assemble_and_compile('${r}', "{name => 'abc::x'}")
      end.to raise_error(Puppet::ParseError, /did not find a value for the name 'abc::x'/)
    end

    it 'will not raise an exception when value is not found default value is nil' do
      resources = assemble_and_compile('${r}', "{name => 'abc::x', default_value => undef}")
      expect(resources).to include('no_value')
    end
  end

  context 'when accessing from outside a module' do
    it 'will both log a warning and raise an exception when key in the function provided module data is not prefixed' do
      logs = []
      Puppet::Util::Log.with_destination(Puppet::Test::LogCollector.new(logs)) do
        Puppet[:code] = "include bad_data\nlookup('bad_data::b')"
        expect { compiler.compile }.to raise_error(Puppet::ParseError, /did not find a value for the name 'bad_data::b'/)
      end
      warnings = logs.select {|log| log.level == :warning }.map {|log| log.message }
      expect(warnings).to include("Module data for module 'bad_data' must use keys qualified with the name of the module")
    end

    it 'will succeed finding prefixed keys even when a key in the function provided module data is not prefixed' do
      logs = []
      resources = nil
      Puppet::Util::Log.with_destination(Puppet::Test::LogCollector.new(logs)) do
        resources = compile_and_get_notifications(<<-END.gsub(/^ {10}/, ''))
          include bad_data
          notify { lookup('bad_data::c'): }
        END
        expect(resources).to include('module_c')
      end
      warnings = logs.select {|log| log.level == :warning }.map {|log| log.message }
      expect(warnings).to include("Module data for module 'bad_data' must use keys qualified with the name of the module")
    end

    it 'will resolve global, environment, and module correctly' do
      Hiera.any_instance.expects(:lookup).with('lookup_options', any_parameters).at_most_once.throws(:no_such_key)
      Hiera.any_instance.expects(:lookup).with('bca::e', any_parameters).returns({ 'k1' => 'global_e1' })
      resources = compile_and_get_notifications(<<-END.gsub(/^ {8}/, '')
        include bca
        $r = lookup(bca::e, Hash[String,String], hash)
        notify { "${r[k1]}_${r[k2]}_${r[k3]}": }
      END
      )
      expect(resources).to include('global_e1_module_bca_e2_env_bca_e3')
    end

    it 'will resolve global and environment correctly when module has no provider' do
      Hiera.any_instance.expects(:lookup).with('lookup_options', any_parameters).at_most_once.throws(:no_such_key)
      Hiera.any_instance.expects(:lookup).with('no_provider::e', any_parameters).returns({ 'k1' => 'global_e1' })
      resources = compile_and_get_notifications(<<-END.gsub(/^ {8}/, '')
        include no_provider
        $r = lookup(no_provider::e, Hash[String,String], hash)
        notify { "${r[k1]}_${r[k2]}_${r[k3]}": }
      END
      )
      expect(resources).to include('global_e1__env_no_provider_e3') # k2 is missing
    end
  end

  context 'when accessing bad data' do
    it 'a warning will be logged when key in the function provided module data is not prefixed' do
      Puppet[:code] = "include bad_data\nlookup('bad_data::c')"
      logs = []
      Puppet::Util::Log.with_destination(Puppet::Test::LogCollector.new(logs)) do
        compiler.compile
      end
      warnings = logs.select {|log| log.level == :warning }.map {|log| log.message }
      expect(warnings).to include("Module data for module 'bad_data' must use keys qualified with the name of the module")
    end

    it 'a warning will be logged when key in the hiera provided module data is not prefixed' do
      Puppet[:code] = "include hieraprovider\nlookup('hieraprovider::test::param_a')"
      logs = []
      Puppet::Util::Log.with_destination(Puppet::Test::LogCollector.new(logs)) do
        compiler.compile
      end
      warnings = logs.select {|log| log.level == :warning }.map {|log| log.message }
      expect(warnings).to include("Module data for module 'hieraprovider' must use keys qualified with the name of the module")
    end
  end

  context 'when accessing empty files' do
    # An empty YAML file is OK and should be treated as a file that contains no keys
    it "will fail normally with a 'did not find a value' error when a yaml file is empty" do
      Puppet[:code] = "include empty_yaml\nlookup('empty_yaml::a')"
      expect { compiler.compile }.to raise_error(Puppet::ParseError, /did not find a value for the name 'empty_yaml::a'/)
    end

    # An empty JSON file is not OK. Should yield a parse error
    it "will fail with a LookupError indicating a parser failure when a json file is empty" do
      Puppet[:code] = "include empty_json\nlookup('empty_json::a')"
      expect { compiler.compile }.to raise_error(Puppet::DataBinding::LookupError, /Unable to parse/)
    end
  end

  context 'when accessing nil values' do
    it 'will find a key with undef value in a yaml file' do
      Puppet[:code] = 'include empty_key_yaml'
      compiler.compile do |catalog|
        lookup_invocation = Puppet::Pops::Lookup::Invocation.new(compiler.topscope, {}, {}, true)
        begin
          Puppet::Pops::Lookup.lookup('empty_key_yaml::has_undef_value',nil, nil, false, nil, lookup_invocation)
        rescue Puppet::Error
        end
        expect(lookup_invocation.explainer.to_s).to eq(<<EOS)
Merge strategy first
  Data Binding "hiera"
    No such key: "empty_key_yaml::has_undef_value"
  Data Provider "FunctionEnvDataProvider"
    No such key: "empty_key_yaml::has_undef_value"
  Module "empty_key_yaml" using Data Provider "Hiera Data Provider, version 4"
    ConfigurationPath "#{environmentpath}/production/modules/empty_key_yaml/hiera.yaml"
    Data Provider "empty_key"
      Path "#{environmentpath}/production/modules/empty_key_yaml/data/empty_key.yaml"
        Original path: "empty_key"
        Found key: "empty_key_yaml::has_undef_value" value: nil
  Merged result: nil
EOS
      end
    end

    it 'will find a key with undef value in a json file' do
      Puppet[:code] = 'include empty_key_json'
      compiler.compile do |catalog|
        lookup_invocation = Puppet::Pops::Lookup::Invocation.new(compiler.topscope, {}, {}, true)
        begin
          Puppet::Pops::Lookup.lookup('empty_key_json::has_undef_value',nil, nil, false, nil, lookup_invocation)
        rescue Puppet::Error
        end
        expect(lookup_invocation.explainer.to_s).to eq(<<EOS)
Merge strategy first
  Data Binding "hiera"
    No such key: "empty_key_json::has_undef_value"
  Data Provider "FunctionEnvDataProvider"
    No such key: "empty_key_json::has_undef_value"
  Module "empty_key_json" using Data Provider "Hiera Data Provider, version 4"
    ConfigurationPath "#{environmentpath}/production/modules/empty_key_json/hiera.yaml"
    Data Provider "empty_key"
      Path "#{environmentpath}/production/modules/empty_key_json/data/empty_key.json"
        Original path: "empty_key"
        Found key: "empty_key_json::has_undef_value" value: nil
  Merged result: nil
EOS
      end
    end
  end

  context 'when using explain' do
    it 'will explain that module is not found' do
      assemble_and_compile('${r}', "'abc::a'") do |scope|
        lookup_invocation = Puppet::Pops::Lookup::Invocation.new(scope, {}, {}, true)
        begin
          Puppet::Pops::Lookup.lookup('ppx::e',nil, nil, false, nil, lookup_invocation)
        rescue Puppet::Error
        end
        expect(lookup_invocation.explainer.to_s).to eq(<<EOS)
Merge strategy first
  Data Binding "hiera"
    No such key: "ppx::e"
  Data Provider "FunctionEnvDataProvider"
    No such key: "ppx::e"
  Module "ppx"
    Module not found
EOS
      end
    end

    it 'will explain that module does not find a key' do
      assemble_and_compile('${r}', "'abc::a'") do |scope|
        lookup_invocation = Puppet::Pops::Lookup::Invocation.new(scope, {}, {}, true)
        begin
          Puppet::Pops::Lookup.lookup('abc::x', nil, nil, false, nil, lookup_invocation)
        rescue Puppet::Error
        end
        expect(lookup_invocation.explainer.to_s).to eq(<<EOS)
Merge strategy first
  Data Binding "hiera"
    No such key: "abc::x"
  Data Provider "FunctionEnvDataProvider"
    No such key: "abc::x"
  Module "abc" using Data Provider "FunctionModuleDataProvider"
    No such key: "abc::x"
EOS
      end
    end

    it 'will explain deep merge results without options' do
      assemble_and_compile('${r}', "'abc::a'") do |scope|
        lookup_invocation = Puppet::Pops::Lookup::Invocation.new(scope, {}, {}, true)
        Puppet::Pops::Lookup.lookup('abc::e', Puppet::Pops::Types::TypeParser.new.parse('Hash[String,String]'), nil, false, 'deep', lookup_invocation)
        expect(lookup_invocation.explainer.to_s).to eq(<<EOS)
Merge strategy deep
  Data Binding "hiera"
    No such key: "abc::e"
  Data Provider "FunctionEnvDataProvider"
    Found key: "abc::e" value: {
      "k1" => "env_e1",
      "k3" => "env_e3"
    }
  Module "abc" using Data Provider "FunctionModuleDataProvider"
    Found key: "abc::e" value: {
      "k1" => "module_e1",
      "k2" => "module_e2"
    }
  Merged result: {
    "k1" => "env_e1",
    "k2" => "module_e2",
    "k3" => "env_e3"
  }
EOS
      end
    end

    it 'will explain deep merge results with options' do
      assemble_and_compile('${r}', "'abc::a'") do |scope|
        Hiera.any_instance.expects(:lookup).with(any_parameters).returns({'k1' => 'global_g1'})
        lookup_invocation = Puppet::Pops::Lookup::Invocation.new(scope, {}, {}, true)
        Puppet::Pops::Lookup.lookup('abc::e', Puppet::Pops::Types::TypeParser.new.parse('Hash[String,String]'), nil, false, {'strategy' => 'deep', 'merge_hash_arrays' => true}, lookup_invocation)
        expect(lookup_invocation.explainer.to_s).to eq(<<EOS)
Merge strategy deep
  Options: {
    "merge_hash_arrays" => true
  }
  Data Binding "hiera"
    Found key: "abc::e" value: {
      "k1" => "global_g1"
    }
  Data Provider "FunctionEnvDataProvider"
    Found key: "abc::e" value: {
      "k1" => "env_e1",
      "k3" => "env_e3"
    }
  Module "abc" using Data Provider "FunctionModuleDataProvider"
    Found key: "abc::e" value: {
      "k1" => "module_e1",
      "k2" => "module_e2"
    }
  Merged result: {
    "k1" => "global_g1",
    "k2" => "module_e2",
    "k3" => "env_e3"
  }
EOS
      end
    end

    it 'will handle path merge when some entries are not found correctly' do
      assemble_and_compile('${r}', "'hieraprovider::test::param_a'") do |scope|
        lookup_invocation = Puppet::Pops::Lookup::Invocation.new(scope, {}, {}, true)
        begin
          Puppet::Pops::Lookup.lookup('hieraprovider::test::not_found', nil, nil, false, nil, lookup_invocation)
        rescue Puppet::DataBinding::LookupError
        end
        expect(lookup_invocation.explainer.to_s).to eq(<<EOS)
Merge strategy first
  Data Binding "hiera"
    No such key: "hieraprovider::test::not_found"
  Data Provider "FunctionEnvDataProvider"
    No such key: "hieraprovider::test::not_found"
  Module "hieraprovider" using Data Provider "Hiera Data Provider, version 4"
    ConfigurationPath "#{environmentpath}/production/modules/hieraprovider/hiera.yaml"
    Data Provider "two paths"
      Merge strategy first
        Path "#{environmentpath}/production/modules/hieraprovider/data/first.json"
          Original path: "first"
          No such key: "hieraprovider::test::not_found"
        Path "#{environmentpath}/production/modules/hieraprovider/data/second_not_present.json"
          Original path: "second_not_present"
          Path not found
EOS
      end
    end

    it 'will explain value access caused by dot notation in key' do
      assemble_and_compile('${r}', "'abc::a'") do |scope|
        lookup_invocation = Puppet::Pops::Lookup::Invocation.new(scope, {}, {}, true)
        Puppet::Pops::Lookup.lookup('abc::f.k1.s1', Puppet::Pops::Types::TypeParser.new.parse('String'), nil, false, nil, lookup_invocation)
        expect(lookup_invocation.explainer.to_s).to eq(<<EOS)
Merge strategy first
  Data Binding "hiera"
    No such key: "abc::f.k1.s1"
  Data Provider "FunctionEnvDataProvider"
    Sub key: "k1.s1"
      Found key: "k1" value: {
        "s1" => "env_f11",
        "s2" => "env_f12"
      }
      Found key: "s1" value: "env_f11"
    Found key: "abc::f.k1.s1" value: "env_f11"
  Merged result: "env_f11"
EOS
      end
    end


    it 'will provide a hash containing all explanation elements' do
      assemble_and_compile('${r}', "'abc::a'") do |scope|
        lookup_invocation = Puppet::Pops::Lookup::Invocation.new(scope, {}, {}, true)
        Puppet::Pops::Lookup.lookup('abc::e', Puppet::Pops::Types::TypeParser.new.parse('Hash[String,String]'), nil, false, {'strategy' => 'deep', 'merge_hash_arrays' => true}, lookup_invocation)
        expect(lookup_invocation.explainer.to_hash).to eq(
            {
              :branches => [
              {
                :key => 'abc::e',
                :event => :not_found,
                :type => :global,
                :name => :hiera
              },
              {
                :key => 'abc::e',
                :value => { 'k1' => 'env_e1', 'k3' => 'env_e3' },
                :event => :found,
                :type => :data_provider,
                :name => 'FunctionEnvDataProvider'
              },
              {
                :key => 'abc::e',
                :value => { 'k1' => 'module_e1', 'k2' => 'module_e2' },
                :event => :found,
                :type => :data_provider,
                :name => 'FunctionModuleDataProvider',
                :module => 'abc'
              }
            ],
              :value => { 'k1' => 'env_e1', 'k2' => 'module_e2', 'k3' => 'env_e3' },
              :event => :result,
              :merge => :deep,
              :options => { 'merge_hash_arrays' => true },
              :type => :merge
            }
          )
      end
    end

    it 'will explain that "lookup_options" is an invalid key' do
      assemble_and_compile('${r}', "'abc::a'") do |scope|
        lookup_invocation = Puppet::Pops::Lookup::Invocation.new(scope, {}, {}, true)
        begin
          Puppet::Pops::Lookup.lookup('lookup_options', nil, nil, false, nil, lookup_invocation)
        rescue Puppet::Error
        end
        expect(lookup_invocation.explainer.to_s).to eq(<<EOS)
Invalid key "lookup_options"
EOS
      end
    end

    it 'will explain that "lookup_options" is an invalid key for any key starting with "lookup_options."' do
      assemble_and_compile('${r}', "'abc::a'") do |scope|
        lookup_invocation = Puppet::Pops::Lookup::Invocation.new(scope, {}, {}, true)
        begin
          Puppet::Pops::Lookup.lookup('lookup_options.subkey', nil, nil, false, nil, lookup_invocation)
        rescue Puppet::Error
        end
        expect(lookup_invocation.explainer.to_s).to eq(<<EOS)
Invalid key "lookup_options"
EOS
      end
    end

  end
end
