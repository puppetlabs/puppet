require 'spec_helper'

require 'puppet_spec/compiler'

describe "Data binding" do
  include PuppetSpec::Files
  include PuppetSpec::Compiler

  let(:dir) { tmpdir("puppetdir") }
  let(:data) {{
    'global' => {
      'testing::binding::value' => 'the value',
      'testing::binding::calling_class' => '%{calling_class}',
      'testing::binding::calling_class_path' => '%{calling_class_path}'
    }
  }}
  let(:hash_data) {{
    'global' => {
      'testing::hash::options' => {
        'key'  => 'value',
        'port' => '80',
        'bind' => 'localhost'
      }
    },
    'agent.example.com' => {
      'testing::hash::options' => {
        'key'  => 'new value',
        'port' => '443'
      }
    }
  }}
  let(:hash_data_with_lopts) {{
    'global' => {
      'testing::hash::options' => {
        'key'  => 'value',
        'port' => '80',
        'bind' => 'localhost'
      }
    },
    'agent.example.com' => {
      'lookup_options' => {
        'testing::hash::options' => {
          'merge' => 'deep'
        }
      },
      'testing::hash::options' => {
        'key'  => 'new value',
        'port' => '443'
      }
    }
  }}

  before do
    # Drop all occurances of cached hiera instances. This will reset @hiera in Puppet::Indirector::Hiera, Testing::DataBinding::Hiera,
    # and Puppet::DataBinding::Hiera. Different classes are active as indirection depending on configuration
    ObjectSpace.each_object(Class).select {|klass| klass <= Puppet::Indirector::Hiera }.each { |klass| klass.instance_variable_set(:@hiera, nil) }
    Puppet[:data_binding_terminus] = 'hiera'
    Puppet[:modulepath] = dir
  end

  context "with testing::binding and global data only" do
    it "looks up global data from hiera" do
      configure_hiera_for_one_tier(data)

      create_manifest_in_module("testing", "binding.pp",
                                <<-MANIFEST)
      class testing::binding($value,
                             $calling_class,
                             $calling_class_path,
                             $calling_module = $module_name) {}
      MANIFEST

      catalog = compile_to_catalog("include testing::binding")
      resource = catalog.resource('Class[testing::binding]')

      expect(resource[:value]).to eq("the value")
      expect(resource[:calling_class]).to eq("testing::binding")
      expect(resource[:calling_class_path]).to eq("testing/binding")
      expect(resource[:calling_module]).to eq("testing")
    end
  end

  context "with testing::hash and global data only" do
    it "looks up global data from hiera" do
      configure_hiera_for_one_tier(hash_data)

      create_manifest_in_module("testing", "hash.pp",
                                <<-MANIFEST)
      class testing::hash($options) {}
      MANIFEST

      catalog = compile_to_catalog("include testing::hash")
      resource = catalog.resource('Class[testing::hash]')

      expect(resource[:options]).to eq({
	'key'  => 'value',
	'port' => '80',
	'bind' => 'localhost'
      })
    end
  end

  context "with custom clientcert" do
    it "merges global data with agent.example.com data from hiera" do
      configure_hiera_for_two_tier(hash_data)

      create_manifest_in_module("testing", "hash.pp",
                                <<-MANIFEST)
      class testing::hash($options) {}
      MANIFEST

      catalog = compile_to_catalog("include testing::hash")
      resource = catalog.resource('Class[testing::hash]')

      expect(resource[:options]).to eq({
            'key'  => 'new value',
            'port' => '443',
      })
    end
  end

  context "with custom clientcert and with lookup_options" do
    it "merges global data with agent.example.com data from hiera" do
      configure_hiera_for_two_tier(hash_data_with_lopts)

      create_manifest_in_module("testing", "hash.pp",
                                <<-MANIFEST)
      class testing::hash($options) {}
      MANIFEST

      catalog = compile_to_catalog("include testing::hash")
      resource = catalog.resource('Class[testing::hash]')

      expect(resource[:options]).to eq({
        'key'  => 'new value',
        'port' => '443',
	      'bind' => 'localhost',
      })
    end
  end


  def configure_hiera_for_one_tier(data)
    hiera_config_file = tmpfile("hiera.yaml")

    File.open(hiera_config_file, 'w') do |f|
      f.write("---
        :yaml:
          :datadir: #{dir}
        :hierarchy: ['global']
        :logger: 'noop'
        :backends: ['yaml']
      ")
    end

    data.each do | file, contents |
      File.open(File.join(dir, "#{file}.yaml"), 'w') do |f|
        f.write(YAML.dump(contents))
      end
    end

    Puppet[:hiera_config] = hiera_config_file
  end

  def configure_hiera_for_two_tier(data)
    hiera_config_file = tmpfile("hiera.yaml")

    File.open(hiera_config_file, 'w') do |f|
      f.write("---
        :yaml:
          :datadir: #{dir}
        :hierarchy: ['agent.example.com', 'global']
        :logger: 'noop'
        :backends: ['yaml']
      ")
    end

    data.each do | file, contents |
      File.open(File.join(dir, "#{file}.yaml"), 'w') do |f|
        f.write(YAML.dump(contents))
      end
    end

    Puppet[:hiera_config] = hiera_config_file
  end

  def create_manifest_in_module(module_name, name, manifest)
    module_dir = File.join(dir, module_name, 'manifests')
    FileUtils.mkdir_p(module_dir)

    File.open(File.join(module_dir, name), 'w') do |f|
      f.write(manifest)
    end
  end
end
