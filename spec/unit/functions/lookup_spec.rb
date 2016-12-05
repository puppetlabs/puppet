#! /usr/bin/env ruby
require 'spec_helper'
require 'puppet_spec/compiler'
require 'puppet_spec/files'
require 'puppet/pops'
require 'deep_merge/core'

describe "when performing lookup" do
  include PuppetSpec::Compiler

  context "using static 'Hiera version 4' fixture" do
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
      node.environment.check_for_reparse
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

    context 'and using normal parameters' do
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
        end.to raise_error(Puppet::ParseError, /Found value has wrong type, expects a String value, got Undef/)
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
        Hiera.any_instance.expects(:lookup).with('abc::f', any_parameters).returns({ 'k1' => { 's1' => 'global_f11' }, 'k2' => { 's3' => 'global_f23' } })
        resources = assemble_and_compile('${r[k1][s1]}_${r[k1][s2]}_${r[k1][s3]}_${r[k2][s1]}_${r[k2][s2]}_${r[k2][s3]}', "'abc::f'", 'Hash[String,Hash[String,String]]', "'deep'")
        expect(resources).to include('global_f11_env_f12_module_f13_env_f21_module_f22_global_f23')
      end

      it 'will propagate resolution_type :array to Hiera when merge == \'unique\'' do
        Hiera.any_instance.expects(:lookup).with('lookup_options', any_parameters).at_most_once.throws(:no_such_key)
        Hiera.any_instance.expects(:lookup).with('abc::c', anything, anything, anything, :array).returns(['global_c'])
        resources = assemble_and_compile('${r[0]}_${r[1]}_${r[2]}', "'abc::c'", 'Array[String]', "'unique'")
        expect(resources).to include('global_c_env_c_module_c')
      end

      it 'will propagate a Hash resolution_type with :behavior => :native to Hiera when merge == \'hash\'' do
        Hiera.any_instance.expects(:lookup).with('lookup_options', any_parameters).at_most_once.throws(:no_such_key)
        Hiera.any_instance.expects(:lookup).with('abc::e', anything, anything, anything, { :behavior => :native }).returns({ 'k1' => 'global_e1' })
        resources = assemble_and_compile('${r[k1]}_${r[k2]}_${r[k3]}', "'abc::e'", 'Hash[String,String]', "{strategy => 'hash'}")
        expect(resources).to include('global_e1_module_e2_env_e3')
      end

      it 'will propagate a Hash resolution_type with :behavior => :deeper to Hiera when merge == \'deep\'' do
        Hiera.any_instance.expects(:lookup).with('lookup_options', any_parameters).at_most_once.throws(:no_such_key)
        Hiera.any_instance.expects(:lookup).with('abc::f', anything, anything, anything, { :behavior => :deeper }).returns({ 'k1' => { 's1' => 'global_f11' }, 'k2' => { 's3' => 'global_f23' } })
        resources = assemble_and_compile('${r[k1][s1]}_${r[k1][s2]}_${r[k1][s3]}_${r[k2][s1]}_${r[k2][s2]}_${r[k2][s3]}', "'abc::f'", 'Hash[String,Hash[String,String]]', "'deep'")
        expect(resources).to include('global_f11_env_f12_module_f13_env_f21_module_f22_global_f23')
      end

      it 'will propagate a Hash resolution_type with symbolic deep merge options to Hiera' do
        Hiera.any_instance.expects(:lookup).with('lookup_options', any_parameters).at_most_once.throws(:no_such_key)
        Hiera.any_instance.expects(:lookup).with('abc::f', anything, anything, anything, { :behavior => :deeper, :knockout_prefix => '--' }).returns({ 'k1' => { 's1' => 'global_f11' }, 'k2' => { 's3' => 'global_f23' } })
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
            /Default value has wrong type, entry 'b' expects a String value, got Integer/)
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
            /Value returned from default block has wrong type, entry 'b' expects a String value, got Integer/)
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

    context 'and using dotted keys' do
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

    context 'and passing a hash as the only parameter' do
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

    context 'and accessing from outside a module' do
      it 'will both log a warning and raise an exception when key in the function provided module data is not prefixed' do
        logs = []
        Puppet::Util::Log.with_destination(Puppet::Test::LogCollector.new(logs)) do
          Puppet[:code] = "include bad_data\nlookup('bad_data::b')"
          expect { compiler.compile }.to raise_error(Puppet::ParseError, /did not find a value for the name 'bad_data::b'/)
        end
        warnings = logs.select { |log| log.level == :warning }.map { |log| log.message }
        expect(warnings).to include("Module 'bad_data': deprecated API function \"bad_data::data\" must use keys qualified with the name of the module")
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
        warnings = logs.select { |log| log.level == :warning }.map { |log| log.message }
        expect(warnings).to include("Module 'bad_data': deprecated API function \"bad_data::data\" must use keys qualified with the name of the module")
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

    context 'and accessing bad data' do
      it 'a warning will be logged when key in the function provided module data is not prefixed' do
        Puppet[:code] = "include bad_data\nlookup('bad_data::c')"
        logs = []
        Puppet::Util::Log.with_destination(Puppet::Test::LogCollector.new(logs)) do
          compiler.compile
        end
        warnings = logs.select { |log| log.level == :warning }.map { |log| log.message }
        expect(warnings).to include("Module 'bad_data': deprecated API function \"bad_data::data\" must use keys qualified with the name of the module")
      end

      it 'a warning will be logged when key in the hiera provided module data is not prefixed' do
        Puppet[:code] = "include hieraprovider\nlookup('hieraprovider::test::param_a')"
        logs = []
        Puppet::Util::Log.with_destination(Puppet::Test::LogCollector.new(logs)) do
          compiler.compile
        end
        warnings = logs.select { |log| log.level == :warning }.map { |log| log.message }
        expect(warnings).to include("Module 'hieraprovider': Hierarchy entry \"two paths\" must use keys qualified with the name of the module")
      end
    end

    context 'and accessing empty files' do
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

    context 'and accessing nil values' do
      it 'will find a key with undef value in a yaml file' do
        Puppet[:code] = 'include empty_key_yaml'
        compiler.compile do |catalog|
          lookup_invocation = Puppet::Pops::Lookup::Invocation.new(compiler.topscope, {}, {}, true)
          begin
            Puppet::Pops::Lookup.lookup('empty_key_yaml::has_undef_value', nil, nil, false, nil, lookup_invocation)
          rescue Puppet::Error
          end
          expect(lookup_invocation.explainer.explain).to include(<<EOS)
      Path "#{environmentpath}/production/modules/empty_key_yaml/data/empty_key.yaml"
        Original path: "empty_key"
        Found key: "empty_key_yaml::has_undef_value" value: nil
EOS
        end
      end

      it 'will find a key with undef value in a json file' do
        Puppet[:code] = 'include empty_key_json'
        compiler.compile do |catalog|
          lookup_invocation = Puppet::Pops::Lookup::Invocation.new(compiler.topscope, {}, {}, true)
          begin
            Puppet::Pops::Lookup.lookup('empty_key_json::has_undef_value', nil, nil, false, nil, lookup_invocation)
          rescue Puppet::Error
          end
          expect(lookup_invocation.explainer.explain).to include(<<EOS)
      Path "#{environmentpath}/production/modules/empty_key_json/data/empty_key.json"
        Original path: "empty_key"
        Found key: "empty_key_json::has_undef_value" value: nil
EOS
        end
      end
    end

    context 'and using explain' do
      it 'will explain that module is not found' do
        Puppet[:code] = 'undef'
        compiler.compile do |catalog|
          lookup_invocation = Puppet::Pops::Lookup::Invocation.new(compiler.topscope, {}, {}, true)
          begin
            Puppet::Pops::Lookup.lookup('ppx::e', nil, nil, false, nil, lookup_invocation)
          rescue Puppet::Error
          end
          expect(lookup_invocation.explainer.explain).to include(<<EOS)
  Module "ppx" not found
EOS
        end
      end

      it 'will explain that module does not find a key' do
        Puppet[:code] = 'undef'
        compiler.compile do |catalog|
          lookup_invocation = Puppet::Pops::Lookup::Invocation.new(compiler.topscope, {}, {}, true)
          begin
            Puppet::Pops::Lookup.lookup('abc::x', nil, nil, false, nil, lookup_invocation)
          rescue Puppet::Error
          end
          expect(lookup_invocation.explainer.explain).to include(<<EOS)
  Module "abc" Data Provider (hiera configuration version 5)
    deprecated API function "abc::data"
      No such key: "abc::x"
EOS
        end
      end

      it 'will explain deep merge results without options' do
        assemble_and_compile('${r}', "'abc::a'") do |scope|
          lookup_invocation = Puppet::Pops::Lookup::Invocation.new(scope, {}, {}, true)
          Puppet::Pops::Lookup.lookup('abc::e', Puppet::Pops::Types::TypeParser.singleton.parse('Hash[String,String]'), nil, false, 'deep', lookup_invocation)
          expect(lookup_invocation.explainer.explain).to eq(<<EOS)
Searching for "abc::e"
  Merge strategy deep
    Data Binding "hiera"
      No such key: "abc::e"
    Environment Data Provider (hiera configuration version 5)
      deprecated API function "environment::data"
        Found key: "abc::e" value: {
          "k1" => "env_e1",
          "k3" => "env_e3"
        }
    Module "abc" Data Provider (hiera configuration version 5)
      deprecated API function "abc::data"
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
          Hiera.any_instance.expects(:lookup).with(any_parameters).returns({ 'k1' => 'global_g1' })
          lookup_invocation = Puppet::Pops::Lookup::Invocation.new(scope, {}, {}, true)
          Puppet::Pops::Lookup.lookup('abc::e', Puppet::Pops::Types::TypeParser.singleton.parse('Hash[String,String]'), nil, false, { 'strategy' => 'deep', 'merge_hash_arrays' => true }, lookup_invocation)
          expect(lookup_invocation.explainer.explain).to include(<<EOS)
  Merge strategy deep
    Options: {
      "merge_hash_arrays" => true
    }
EOS
        end
      end

      it 'will handle merge when no entries are not found' do
        assemble_and_compile('${r}', "'hieraprovider::test::param_a'") do |scope|
          lookup_invocation = Puppet::Pops::Lookup::Invocation.new(scope, {}, {}, true)
          begin
            Puppet::Pops::Lookup.lookup('hieraprovider::test::not_found', nil, nil, false, 'deep', lookup_invocation)
          rescue Puppet::DataBinding::LookupError
          end
          expect(lookup_invocation.explainer.explain).to eq(<<EOS)
Searching for "hieraprovider::test::not_found"
  Merge strategy deep
    Data Binding "hiera"
      No such key: "hieraprovider::test::not_found"
    Environment Data Provider (hiera configuration version 5)
      deprecated API function "environment::data"
        No such key: "hieraprovider::test::not_found"
    Module "hieraprovider" Data Provider (hiera configuration version 4)
      Using configuration "#{environmentpath}/production/modules/hieraprovider/hiera.yaml"
      Hierarchy entry "two paths"
        Merge strategy deep
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
          Puppet::Pops::Lookup.lookup('abc::f.k1.s1', Puppet::Pops::Types::TypeParser.singleton.parse('String'), nil, false, nil, lookup_invocation)
          expect(lookup_invocation.explainer.explain).to include(<<EOS)
  Sub key: "k1.s1"
    Found key: "k1" value: {
      "s1" => "env_f11",
      "s2" => "env_f12"
    }
    Found key: "s1" value: "env_f11"
EOS
        end
      end


      it 'will provide a hash containing all explanation elements' do
        assemble_and_compile('${r}', "'abc::a'") do |scope|
          lookup_invocation = Puppet::Pops::Lookup::Invocation.new(scope, {}, {}, true)
          Puppet::Pops::Lookup.lookup('abc::e', Puppet::Pops::Types::TypeParser.singleton.parse('Hash[String,String]'), nil, false, { 'strategy' => 'deep', 'merge_hash_arrays' => true }, lookup_invocation)
          expect(lookup_invocation.explainer.to_hash).to eq(
            {
              :type => :root,
              :key => 'abc::e',
              :branches => [
                {
                  :value => { 'k1' => 'env_e1', 'k2' => 'module_e2', 'k3' => 'env_e3' },
                  :event => :result,
                  :merge => :deep,
                  :options => { 'merge_hash_arrays' => true },
                  :type => :merge,
                  :branches => [
                    {
                      :key => 'abc::e',
                      :event => :not_found,
                      :type => :global,
                      :name => :hiera
                    },
                    {
                      :type => :data_provider,
                      :name => 'Environment Data Provider (hiera configuration version 5)',
                      :branches => [
                        {
                          :type => :data_provider,
                          :name => 'deprecated API function "environment::data"',
                          :key => 'abc::e',
                          :value => { 'k1' => 'env_e1', 'k3' => 'env_e3' },
                          :event => :found
                        }
                      ]
                    },
                    {
                      :type => :data_provider,
                      :name => 'Module "abc" Data Provider (hiera configuration version 5)',
                      :module => 'abc',
                      :branches => [
                        {
                          :type => :data_provider,
                          :name => 'deprecated API function "abc::data"',
                          :key => 'abc::e',
                          :event => :found,
                          :value => {
                            'k1' => 'module_e1',
                            'k2' => 'module_e2'
                          }
                        }
                      ]
                    }
                  ]
                }
              ]
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
          expect(lookup_invocation.explainer.explain).to eq(<<EOS)
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
          expect(lookup_invocation.explainer.explain).to eq(<<EOS)
Invalid key "lookup_options"
EOS
        end
      end
    end
  end

  context 'using generated fixture' do
    include PuppetSpec::Files

    context 'with an environment' do
      let(:env_name) { 'spec' }
      let(:env_dir) { tmpdir('environments') }
      let(:environment_files) do
        {
          env_name => {
            'modules' => {},
            'hiera.yaml' => <<-YAML.unindent,
            ---
            version: 5
            hierarchy:
              - name: "Common"
                data_hash: yaml_data
                path: "common.yaml"
          YAML
          'data' => {
            'common.yaml' => <<-YAML.unindent
              ---
              a: value a
              mod_a::a: value mod_a::a (from environment)
              mod_a::hash_a:
                a: value mod_a::hash_a.a (from environment)
              mod_a::hash_b:
                a: value mod_a::hash_b.a (from environment)
              lookup_options:
                mod_a::hash_b:
                  merge: hash
          YAML
          }
          }
        }
      end

      let(:logs) { [] }
      let(:notices) { logs.select { |log| log.level == :notice }.map { |log| log.message } }
      let(:warnings) { logs.select { |log| log.level == :warning }.map { |log| log.message } }
      let(:env) { Puppet::Node::Environment.create(env_name.to_sym, [File.join(populated_env_dir, env_name, 'modules')]) }
      let(:environments) { Puppet::Environments::Directories.new(populated_env_dir, []) }
      let(:node) { Puppet::Node.new('test_lookup', :environment => env) }
      let(:compiler) { Puppet::Parser::Compiler.new(node) }
      let(:defaults) {
        {
          'mod_a::xd' => 'value mod_a::xd (from default)',
          'mod_a::xd_found' => 'value mod_a::xd_found (from default)',
          'scope_xd' => 'value scope_xd (from default)'
        }}
      let(:overrides) {
        {
          'mod_a::xo' => 'value mod_a::xo (from override)',
          'scope_xo' => 'value scope_xo (from override)'
        }}
      let(:invocation_with_explain) { Puppet::Pops::Lookup::Invocation.new(compiler.topscope, {}, {}, true) }
      let(:explanation) { invocation_with_explain.explainer.explain }

      let(:populated_env_dir) do
        dir_contained_in(env_dir, environment_files)
        env_dir
      end

      around(:each) do |example|
        Puppet.override(:environments => environments, :current_environment => env) do
          example.run
        end
      end

      def collect_notices(code, explain = false, &block)
        Puppet[:code] = code
        Puppet::Util::Log.with_destination(Puppet::Test::LogCollector.new(logs)) do
          scope = compiler.topscope
          scope['scope_scalar'] = 'scope scalar value'
          scope['scope_hash'] = { 'a' => 'scope hash a', 'b' => 'scope hash b' }
          if explain
            begin
              invocation_with_explain.lookup('dummy', nil) do
                if block_given?
                  compiler.compile { |catalog| block.call(compiler.topscope); catalog }
                else
                  compiler.compile
                end
              end
            rescue Puppet::DataBinding::LookupError => e
              invocation_with_explain.report_text { e.message }
            end
          else
            if block_given?
              compiler.compile { |catalog| block.call(compiler.topscope); catalog }
            else
              compiler.compile
            end
          end
        end
        nil
      end

      def lookup(key, options = {}, explain = false)
        nc_opts = options.empty? ? '' : ", #{Puppet::Pops::Types::TypeFormatter.string(options)}"
        keys = key.is_a?(Array) ? key : [key]
        collect_notices(keys.map { |k| "notice(String(lookup('#{k}'#{nc_opts}), '%p'))" }.join("\n"), explain)
        if explain
          explanation
        else
          result = notices.map { |n| Puppet::Pops::Types::TypeParser.singleton.parse_literal(n) }
          key.is_a?(Array) ? result : result[0]
        end
      end

      def explain(key, options = {})
        lookup(key, options, true)[1]
        explanation
      end

      it 'finds data in the environment' do
        expect(lookup('a')).to eql('value a')
      end

      context 'that has no lookup configured' do
        let(:environment_files) do
          {
            env_name => {
              'modules' => {},
              'data' => {
                'common.yaml' => <<-YAML.unindent
                ---
                a: value a
              YAML
              }
            }
          }
        end

        it 'does not find data in the environment' do
          expect { lookup('a') }.to raise_error(Puppet::DataBinding::LookupError, /did not find a value for the name 'a'/)
        end

        context "but an environment.conf with 'environment_data_provider=hiera'" do
          let(:environment_files_1) do
            DeepMerge.deep_merge!(environment_files, 'environment.conf' => "environment_data_provider=hiera\n")
          end

          let(:populated_env_dir) do
            dir_contained_in(env_dir, DeepMerge.deep_merge!(environment_files, env_name => environment_files_1))
            env_dir
          end

          it 'finds data in the environment and reports deprecation warning for environment.conf' do
            expect(lookup('a')).to eql('value a')
            expect(warnings).to include(/Defining environment_data_provider='hiera' in environment.conf is deprecated. A 'hiera.yaml' file should be used instead/)
          end

          context 'and a hiera.yaml file' do
            let(:environment_files_2) { DeepMerge.deep_merge!(environment_files_1,'hiera.yaml' => <<-YAML.unindent) }
              ---
              version: 4
              hierarchy:
                - name: common
                  backend: yaml
              YAML

            let(:populated_env_dir) do
              dir_contained_in(env_dir, DeepMerge.deep_merge!(environment_files, env_name => environment_files_2))
              env_dir
            end

            it 'finds data in the environment and reports deprecation warnings for both environment.conf and hiera.yaml' do
              expect(lookup('a')).to eql('value a')
              expect(warnings).to include(/Defining environment_data_provider='hiera' in environment.conf is deprecated/)
              expect(warnings).to include(/Use of 'hiera.yaml' version 4 is deprecated. It should be converted to version 5/)
            end
          end
        end
      end

      context "but an environment.conf with 'environment_data_provider=function'" do
        let(:environment_files) do
          {
            env_name => {
              'environment.conf' => "environment_data_provider=function\n",
              'functions' => { 'data.pp' => <<-PUPPET.unindent }
                    function environment::data() {
                      { 'a' => 'value a' }
                    }
              PUPPET
            }
          }
        end

        it 'finds data in the environment and reports deprecation warning for environment.conf' do
          expect(lookup('a')).to eql('value a')
          expect(warnings).to include(/Defining environment_data_provider='function' in environment.conf is deprecated. A 'hiera.yaml' file should be used instead/)
          expect(warnings).to include(/Using of legacy data provider function 'environment::data'. Please convert to a 'data_hash' function/)
        end
      end

      context 'and a module' do
        let(:mod_a_files) { {} }

        let(:populated_env_dir) do
          dir_contained_in(env_dir, DeepMerge.deep_merge!(environment_files, env_name => { 'modules' => mod_a_files }))
          env_dir
        end

        context 'that has no lookup configured' do
          let(:mod_a_files) do
            {
              'mod_a' => {
                'data' => {
                  'common.yaml' => <<-YAML.unindent
                  ---
                  mod_a::b: value mod_a::b (from mod_a)
                YAML
                }
              }
            }
          end

          it 'does not find data in the module' do
            expect { lookup('mod_a::b') }.to raise_error(Puppet::DataBinding::LookupError, /did not find a value for the name 'mod_a::b'/)
          end

          context "but a metadata.json with 'module_data_provider=hiera'" do
            let(:mod_a_files_1) { DeepMerge.deep_merge!(mod_a_files, 'mod_a' => { 'metadata.json' => <<-JSON.unindent }) }
                {
                    "name": "example/mod_a",
                    "version": "0.0.2",
                    "source": "git@github.com/example/mod_a.git",
                    "dependencies": [],
                    "author": "Bob the Builder",
                    "license": "Apache-2.0",
                    "data_provider": "hiera"
                }
                JSON

            let(:populated_env_dir) do
              dir_contained_in(env_dir, DeepMerge.deep_merge!(environment_files, env_name => { 'modules' => mod_a_files_1 }))
              env_dir
            end

            it 'finds data in the module and reports deprecation warning for metadata.json' do
              expect(lookup('mod_a::b')).to eql('value mod_a::b (from mod_a)')
              expect(warnings).to include(/Defining "data_provider": "hiera" in metadata.json is deprecated. A 'hiera.yaml' file should be used instead/)
            end

            context 'and a hiera.yaml file' do
              let(:mod_a_files_2) { DeepMerge.deep_merge!(mod_a_files_1, 'mod_a' => { 'hiera.yaml' => <<-YAML.unindent }) }
              ---
              version: 4
              hierarchy:
                - name: common
                  backend: yaml
              YAML

              let(:populated_env_dir) do
                dir_contained_in(env_dir, DeepMerge.deep_merge!(environment_files, env_name => { 'modules' => mod_a_files_2 }))
                env_dir
              end

              it 'finds data in the module and reports deprecation warnings for both metadata.json and hiera.yaml' do
                expect(lookup('mod_a::b')).to eql('value mod_a::b (from mod_a)')
                expect(warnings).to include(/Defining "data_provider": "hiera" in metadata.json is deprecated/)
                expect(warnings).to include(/Use of 'hiera.yaml' version 4 is deprecated. It should be converted to version 5/)
              end
            end
          end
        end

        context 'using a data_hash that reads a yaml file' do
          let(:mod_a_files) do
            {
              'mod_a' => {
                'data' => {
                  'common.yaml' => <<-YAML.unindent
                  ---
                  mod_a::a: value mod_a::a (from mod_a)
                  mod_a::b: value mod_a::b (from mod_a)
                  mod_a::xo: value mod_a::xo (from mod_a)
                  mod_a::xd_found: value mod_a::xd_found (from mod_a)
                  mod_a::interpolate_xo: "-- %{lookup('mod_a::xo')} --"
                  mod_a::interpolate_xd: "-- %{lookup('mod_a::xd')} --"
                  mod_a::interpolate_scope_xo: "-- %{scope_xo} --"
                  mod_a::interpolate_scope_xd: "-- %{scope_xd} --"
                  mod_a::hash_a:
                    a: value mod_a::hash_a.a (from mod_a)
                    b: value mod_a::hash_a.b (from mod_a)
                  mod_a::hash_b:
                    a: value mod_a::hash_b.a (from mod_a)
                    b: value mod_a::hash_b.b (from mod_a)
                  mod_a::interpolated: "-- %{lookup('mod_a::a')} --"
                  mod_a::a_a: "-- %{lookup('mod_a::hash_a.a')} --"
                  mod_a::a_b: "-- %{lookup('mod_a::hash_a.b')} --"
                  mod_a::b_a: "-- %{lookup('mod_a::hash_b.a')} --"
                  mod_a::b_b: "-- %{lookup('mod_a::hash_b.b')} --"
                  mod_a::interpolate_array:
                    - "-- %{lookup('mod_a::a')} --"
                    - "-- %{lookup('mod_a::b')} --"
                  mod_a::interpolate_literal: "-- %{literal('hello')} --"
                  mod_a::interpolate_scope: "-- %{scope_scalar} --"
                  mod_a::interpolate_scope_not_found: "-- %{scope_nope} --"
                  mod_a::interpolate_scope_dig: "-- %{scope_hash.a} --"
                  mod_a::interpolate_scope_dig_not_found: "-- %{scope_hash.nope} --"
                  mod_a::quoted_interpolation: '-- %{lookup(''"mod_a::a.quoted.key"'')} --'
                  "mod_a::a.quoted.key": "value mod_a::a.quoted.key (from mod_a)"
                YAML
                },
                'hiera.yaml' => <<-YAML.unindent,
                ---
                version: 5
                hierarchy:
                  - name: "Common"
                    data_hash: yaml_data
                    path: "common.yaml"
              YAML
              }
            }
          end

          it 'finds data in the module' do
            expect(lookup('mod_a::b')).to eql('value mod_a::b (from mod_a)')
          end

          it 'environment data has higher priority than module data' do
            expect(lookup('mod_a::a')).to eql('value mod_a::a (from environment)')
          end

          it 'environment data has higher priority than module data in interpolated module data' do
            expect(lookup('mod_a::interpolated')).to eql('-- value mod_a::a (from environment) --')
          end

          it 'overrides have higher priority than found data' do
            expect(lookup('mod_a::xo', { 'override' => overrides })).to eql('value mod_a::xo (from override)')
          end

          it 'overrides have higher priority than found data in lookup interpolations' do
            expect(lookup('mod_a::interpolate_xo', { 'override' => overrides })).to eql('-- value mod_a::xo (from override) --')
          end

          it 'overrides have higher priority than found data in scope interpolations' do
            expect(lookup('mod_a::interpolate_scope_xo', { 'override' => overrides })).to eql('-- value scope_xo (from override) --')
          end

          it 'defaults have lower priority than found data' do
            expect(lookup('mod_a::xd_found', { 'default_values_hash' => defaults })).to eql('value mod_a::xd_found (from mod_a)')
          end

          it 'defaults are used when data is not found' do
            expect(lookup('mod_a::xd', { 'default_values_hash' => defaults })).to eql('value mod_a::xd (from default)')
          end

          it 'defaults are used when data is not found in lookup interpolations' do
            expect(lookup('mod_a::interpolate_xd', { 'default_values_hash' => defaults })).to eql('-- value mod_a::xd (from default) --')
          end

          it 'defaults are used when data is not found in scope interpolations' do
            expect(lookup('mod_a::interpolate_scope_xd', { 'default_values_hash' => defaults })).to eql('-- value scope_xd (from default) --')
          end

          it 'merges hashes from environment and module unless strategy hash is used' do
            expect(lookup('mod_a::hash_a')).to eql({'a' => 'value mod_a::hash_a.a (from environment)'})
          end

          it 'merges hashes from environment and module when merge strategy hash is used' do
            expect(lookup('mod_a::hash_a', :merge => 'hash')).to eql(
              {'a' => 'value mod_a::hash_a.a (from environment)', 'b' => 'value mod_a::hash_a.b (from mod_a)'})
          end

          it 'will not merge hashes from environment and module in interpolated expressions' do
            expect(lookup(['mod_a::a_a', 'mod_a::a_b'])).to eql(
              ['-- value mod_a::hash_a.a (from environment) --', '--  --']) # root key found in environment, no hash merge is performed
          end

          it 'interpolates arrays' do
            expect(lookup('mod_a::interpolate_array')).to eql(['-- value mod_a::a (from environment) --', '-- value mod_a::b (from mod_a) --'])
          end

          it 'can dig into arrays using subkeys' do
            expect(lookup('mod_a::interpolate_array.1')).to eql('-- value mod_a::b (from mod_a) --')
          end

          it 'treats an out of range subkey as not found' do
            expect(explain('mod_a::interpolate_array.2')).to match(/No such key: "2"/)
          end

          it 'interpolates a literal' do
            expect(lookup('mod_a::interpolate_literal')).to eql('-- hello --')
          end

          it 'interpolates scalar from scope' do
            expect(lookup('mod_a::interpolate_scope')).to eql('-- scope scalar value --')
          end

          it 'interpolates not found in scope as empty string' do
            expect(lookup('mod_a::interpolate_scope_not_found')).to eql('--  --')
          end

          it 'interpolates dotted key from scope' do
            expect(lookup('mod_a::interpolate_scope_dig')).to eql('-- scope hash a --')
          end

          it 'treates interpolated dotted key but not found in scope as empty string' do
            expect(lookup('mod_a::interpolate_scope_dig_not_found')).to eql('--  --')
          end

          it 'can use quoted keys in interpolation' do
            expect(lookup('mod_a::quoted_interpolation')).to eql('-- value mod_a::a.quoted.key (from mod_a) --') # root key found in environment, no hash merge is performed
          end

          it 'merges hashes from environment and module in interpolated expressions if hash merge is specified in lookup options' do
            expect(lookup(['mod_a::b_a', 'mod_a::b_b'])).to eql(
              ['-- value mod_a::hash_b.a (from environment) --', '-- value mod_a::hash_b.b (from mod_a) --'])
          end
        end

        context 'using a lookup_key that is a puppet function' do
          let(:mod_a_files) do
            {
              'mod_a' => {
                'functions' => {
                  'pp_lookup_key.pp' => <<-PUPPET.unindent
                  function mod_a::pp_lookup_key($key, $options, $context) {
                    case $key {
                      'mod_a::really_interpolated': { $context.interpolate("-- %{lookup('mod_a::a')} --") }
                      'mod_a::recursive': { lookup($key) }
                      default: {
                        if $context.cache_has_key(mod_a::a) {
                          $context.explain || { 'reusing cache' }
                        } else {
                          $context.explain || { 'initializing cache' }
                          $context.cache_all({
                            mod_a::a => 'value mod_a::a (from mod_a)',
                            mod_a::b => 'value mod_a::b (from mod_a)',
                            mod_a::c => 'value mod_a::c (from mod_a)',
                            mod_a::hash_a => {
                              a => 'value mod_a::hash_a.a (from mod_a)',
                              b => 'value mod_a::hash_a.b (from mod_a)'
                            },
                            mod_a::hash_b => {
                              a => 'value mod_a::hash_b.a (from mod_a)',
                              b => 'value mod_a::hash_b.b (from mod_a)'
                            },
                            mod_a::interpolated => "-- %{lookup('mod_a::a')} --",
                            mod_a::a_a => "-- %{lookup('mod_a::hash_a.a')} --",
                            mod_a::a_b => "-- %{lookup('mod_a::hash_a.b')} --",
                            mod_a::b_a => "-- %{lookup('mod_a::hash_b.a')} --",
                            mod_a::b_b => "-- %{lookup('mod_a::hash_b.b')} --",
                            'mod_a::a.quoted.key' => 'value mod_a::a.quoted.key (from mod_a)',
                            mod_a::sensitive => Sensitive('reduct me please'),
                            mod_a::type => Object[{name => 'FindMe', 'attributes' => {'x' => String}}],
                            mod_a::version => SemVer('3.4.1'),
                            mod_a::version_range => SemVerRange('>=3.4.1'),
                            mod_a::timestamp => Timestamp("1994-03-25T19:30:00"),
                            mod_a::timespan => Timespan("3-10:00:00")
                          })
                        }
                        if !$context.cache_has_key($key) {
                          $context.not_found
                        }
                        $context.explain || { "returning value for $key" }
                        $context.cached_value($key)
                      }
                    }
                  }
                PUPPET
                },
                'hiera.yaml' => <<-YAML.unindent,
                ---
                version: 5
                hierarchy:
                  - name: "Common"
                    lookup_key: mod_a::pp_lookup_key
              YAML
              }
            }
          end

          it 'finds data in the module' do
            expect(lookup('mod_a::b')).to eql('value mod_a::b (from mod_a)')
          end

          it 'environment data has higher priority than module data' do
            expect(lookup('mod_a::a')).to eql('value mod_a::a (from environment)')
          end

          it 'finds quoted keys in the module' do
            expect(lookup('"mod_a::a.quoted.key"')).to eql('value mod_a::a.quoted.key (from mod_a)')
          end

          it 'will not resolve interpolated expressions' do
            expect(lookup('mod_a::interpolated')).to eql("-- %{lookup('mod_a::a')} --")
          end

          it 'resolves interpolated expressions using Context#interpolate' do
            expect(lookup('mod_a::really_interpolated')).to eql("-- value mod_a::a (from environment) --")
          end

          it 'will not merge hashes from environment and module unless strategy hash is used' do
            expect(lookup('mod_a::hash_a')).to eql({ 'a' => 'value mod_a::hash_a.a (from environment)' })
          end

          it 'merges hashes from environment and module when merge strategy hash is used' do
            expect(lookup('mod_a::hash_a', :merge => 'hash')).to eql({ 'a' => 'value mod_a::hash_a.a (from environment)', 'b' => 'value mod_a::hash_a.b (from mod_a)' })
          end

          it 'traps recursive lookup trapped' do
            expect(explain('mod_a::recursive')).to include('Recursive lookup detected')
          end

          it 'private cache is persisted over multiple calls' do
            collect_notices("notice(lookup('mod_a::b')) notice(lookup('mod_a::c'))", true)
            expect(notices).to eql(['value mod_a::b (from mod_a)', 'value mod_a::c (from mod_a)'])
            expect(explanation).to match(/initializing cache.*reusing cache/m)
            expect(explanation).not_to match(/initializing cache.*initializing cache/m)
          end

          it 'the same key is requested only once' do
            collect_notices("notice(lookup('mod_a::b')) notice(lookup('mod_a::b'))", true)
            expect(notices).to eql(['value mod_a::b (from mod_a)', 'value mod_a::b (from mod_a)'])
            expect(explanation).to match(/Found key: "mod_a::b".*Found key: "mod_a::b"/m)
            expect(explanation).to match(/returning value for mod_a::b/m)
            expect(explanation).not_to match(/returning value for mod_a::b.*returning value for mod_a::b/m)
          end

          context 'and calling function via API' do
            let(:lookup_func) do
              Puppet.lookup(:loaders).puppet_system_loader.load(:function, 'lookup')
            end

            it 'finds and delivers rich data' do
              collect_notices("notice('success')") do |scope|
                expect(lookup_func.call(scope, 'mod_a::sensitive')).to be_a(Puppet::Pops::Types::PSensitiveType::Sensitive)
                expect(lookup_func.call(scope, 'mod_a::type')).to be_a(Puppet::Pops::Types::PObjectType)
                expect(lookup_func.call(scope, 'mod_a::version')).to eql(SemanticPuppet::Version.parse('3.4.1'))
                expect(lookup_func.call(scope, 'mod_a::version_range')).to eql(SemanticPuppet::VersionRange.parse('>=3.4.1'))
                expect(lookup_func.call(scope, 'mod_a::timestamp')).to eql(Puppet::Pops::Time::Timestamp.parse('1994-03-25T19:30:00'))
                expect(lookup_func.call(scope, 'mod_a::timespan')).to eql(Puppet::Pops::Time::Timespan.parse('3-10:00:00'))
              end
              expect(notices).to eql(['success'])
            end
          end
        end

        context 'using a data_dig that is a ruby function' do
          let(:mod_a_files) do
            {
              'mod_a' => {
                'lib' => {
                  'puppet' => {
                    'functions' => {
                      'mod_a' => {
                        'ruby_dig.rb' => <<-RUBY.unindent
                        Puppet::Functions.create_function(:'mod_a::ruby_dig') do
                          dispatch :ruby_dig do
                            param 'Array[String[1]]', :segments
                            param 'Hash[String,Any]', :options
                            param 'Puppet::LookupContext', :context
                          end

                          def ruby_dig(segments, options, context)
                            sub_segments = segments.dup
                            root_key = sub_segments.shift
                            case root_key
                            when 'mod_a::options'
                              hash = { 'mod_a::options' => options }
                            when 'mod_a::lookup'
                              return call_function('lookup', segments.join('.'))
                            else
                              hash = {
                                'mod_a::a' => 'value mod_a::a (from mod_a)',
                                'mod_a::b' => 'value mod_a::b (from mod_a)',
                                'mod_a::hash_a' => {
                                  'a' => 'value mod_a::hash_a.a (from mod_a)',
                                  'b' => 'value mod_a::hash_a.b (from mod_a)'
                                },
                                'mod_a::hash_b' => {
                                  'a' => 'value mod_a::hash_b.a (from mod_a)',
                                  'b' => 'value mod_a::hash_b.b (from mod_a)'
                                },
                                'mod_a::interpolated' => "-- %{lookup('mod_a::a')} --",
                                'mod_a::really_interpolated' => "-- %{lookup('mod_a::a')} --",
                                'mod_a::a_a' => "-- %{lookup('mod_a::hash_a.a')} --",
                                'mod_a::a_b' => "-- %{lookup('mod_a::hash_a.b')} --",
                                'mod_a::b_a' => "-- %{lookup('mod_a::hash_b.a')} --",
                                'mod_a::b_b' => "-- %{lookup('mod_a::hash_b.b')} --",
                                'mod_a::bad_type' => :oops,
                                'mod_a::bad_type_in_hash' => { 'a' => :oops },
                              }
                              end
                            context.not_found unless hash.include?(root_key)
                            value = sub_segments.reduce(hash[root_key]) do |memo, segment|
                              context.not_found unless memo.is_a?(Hash) && memo.include?(segment)
                              memo[segment]
                            end
                            root_key == 'mod_a::really_interpolated' ? context.interpolate(value) : value
                          end
                        end
                      RUBY
                      }
                    }
                  }
                },
                'hiera.yaml' => <<-YAML.unindent,
                ---
                version: 5
                hierarchy:
                  - name: "Common"
                    data_dig: mod_a::ruby_dig
                    uri: "http://www.example.com/passed/as/option"
                    options:
                      option_a: Option value a
                      option_b:
                        x: Option value b.x
                        y: Option value b.y
              YAML
              }
            }
          end

          it 'finds data in the module' do
            expect(lookup('mod_a::b')).to eql('value mod_a::b (from mod_a)')
          end

          it 'environment data has higher priority than module data' do
            expect(lookup('mod_a::a')).to eql('value mod_a::a (from environment)')
          end

          it 'will not resolve interpolated expressions' do
            expect(lookup('mod_a::interpolated')).to eql("-- %{lookup('mod_a::a')} --")
          end

          it 'resolves interpolated expressions using Context#interpolate' do
            expect(lookup('mod_a::really_interpolated')).to eql("-- value mod_a::a (from environment) --")
          end

          it 'does not accept return of runtime type from function' do
            expect(explain('mod_a::bad_type')).to include('Value returned from Hierarchy entry "Common" has wrong type')
          end

          it 'does not accept return of runtime type embedded in hash from function' do
            expect(explain('mod_a::bad_type_in_hash')).to include('Value returned from Hierarchy entry "Common" has wrong type')
          end

          it 'will not merge hashes from environment and module unless strategy hash is used' do
            expect(lookup('mod_a::hash_a')).to eql({'a' => 'value mod_a::hash_a.a (from environment)'})
          end

          it 'hierarchy entry options are passed to the function' do
            expect(lookup('mod_a::options.option_b.x')).to eql('Option value b.x')
          end

          it 'hierarchy entry "uri" is passed as location option to the function' do
            expect(lookup('mod_a::options.uri')).to eql('http://www.example.com/passed/as/option')
          end

          it 'recursive lookup is trapped' do
            expect(explain('mod_a::lookup.mod_a::lookup')).to include('Recursive lookup detected')
          end

          context 'with merge strategy hash' do
            it 'merges hashes from environment and module' do
              expect(lookup('mod_a::hash_a', :merge => 'hash')).to eql({'a' => 'value mod_a::hash_a.a (from environment)', 'b' => 'value mod_a::hash_a.b (from mod_a)'})
            end

            it 'will "undig" value from data_dig function, merge root hashes, and then dig to get values by subkey' do
              expect(lookup(['mod_a::hash_a.a', 'mod_a::hash_a.b'], :merge => 'hash')).to eql(
                ['value mod_a::hash_a.a (from environment)', 'value mod_a::hash_a.b (from mod_a)'])
            end
          end
        end
      end
    end
  end
end
