require 'spec_helper'

require 'puppet_spec/compiler'

describe "Data binding" do
  include PuppetSpec::Files
  include PuppetSpec::Compiler

  let(:dir) { tmpdir("puppetdir") }
  let(:data) {{
    'global' => {
      "testing::binding::value" => "the value",
      "testing::binding::calling_class" => "%{calling_class}",
      "testing::binding::calling_class_path" => "%{calling_class_path}"
    },
    'client1' => {
      "testing::binding::value" => "value override"
    }
  }}


  before do
    Puppet[:data_binding_terminus] = "hiera"
    Puppet[:modulepath] = dir
  end

  it "looks up data from hiera" do
    configure_hiera_for(data)

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

  it "works with the puppet backend configured, although it can't use it for lookup" do
    configure_hiera_for_puppet
    create_manifest_in_module("testing", "binding.pp",
                              <<-MANIFEST)
    # lookup via the puppet backend to ensure it works
    class testing::binding($value = hiera('variable')) {}
    MANIFEST

    create_manifest_in_module("testing", "data.pp",
                              <<-MANIFEST)
    class testing::data (
      $variable = "the value"
    ) { }
    MANIFEST

    catalog = compile_to_catalog("include testing::data")
    resource = catalog.resource('Class[testing::data]')

    expect(resource[:variable]).to eq("the value")
  end

  def configure_hiera_for(data)
    hiera_config_file = tmpfile("hiera.yaml")

    File.open(hiera_config_file, 'w') do |f|
      f.write("---
        :yaml:
          :datadir: #{dir}
        :hierarchy: ['%{clientcert}', 'global']
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

  def configure_hiera_for_puppet
    hiera_config_file = tmpfile("hiera.yaml")

    File.open(hiera_config_file, 'w') do |f|
      f.write("---
        :logger: 'noop'
        :backends: ['puppet']
      ")
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
