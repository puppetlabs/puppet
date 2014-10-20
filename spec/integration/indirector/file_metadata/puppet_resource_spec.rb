#! /usr/bin/env ruby
require 'spec_helper'
require 'puppet_spec/files'

describe "puppet resource" do
  include PuppetSpec::Files

  let(:confdir) { Puppet[:confdir] }
  let(:environmentpath) { File.expand_path("envdir", confdir) }
  let(:temp_dir) { tmpdir('testingdir') }
  let(:source_temp_dir) { tmpdir('sourcedir') }
  let(:expected_file) { "#{temp_dir}/some_source_file.txt" }
  let(:source_file) { File.expand_path('some_source_file.txt', source_temp_dir) }

  it "acts like puppet apply while using ral" do
    Puppet[:environmentpath] = environmentpath
    Puppet.initialize_settings

    File.open(source_file, 'wb') { |f| f.write("One Shrubbery") }

    catalog = Puppet::Resource::Catalog.new
    resource = Puppet::Resource.new(:file, temp_dir, :parameters => {
      'ensure' => 'directory',
      'source' => source_temp_dir,
      'recurse' => true,
    })

    catalog.add_resource resource.to_ral
    catalog.apply

    expect(File).to exist(expected_file)
  end
end
