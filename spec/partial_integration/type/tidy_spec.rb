#! /usr/bin/env ruby
require 'spec_helper'

require 'puppet_spec/compiler'
require 'puppet_spec/files'
require 'puppet/file_bucket/dipper'

describe Puppet::Type.type(:tidy) do
  include PuppetSpec::Files
  include PuppetSpec::Compiler

  before do
    Puppet::Util::Storage.stubs(:store)
  end

  it "should be able to recursively remove directories" do
    dir = tmpfile("tidy_testing")
    FileUtils.mkdir_p(File.join(dir, "foo", "bar"))

    apply_compiled_manifest(<<-MANIFEST)
      tidy { '#{dir}':
        recurse => true,
        rmdirs  => true,
      }
    MANIFEST

    expect(Puppet::FileSystem.directory?(dir)).to be_falsey
  end

  # Testing #355.
  it "should be able to remove dead links", :if => Puppet.features.manages_symlinks? do
    dir = tmpfile("tidy_link_testing")
    link = File.join(dir, "link")
    target = tmpfile("no_such_file_tidy_link_testing")
    Dir.mkdir(dir)
    Puppet::FileSystem.symlink(target, link)

    apply_compiled_manifest(<<-MANIFEST)
      tidy { '#{dir}':
        recurse => true,
      }
    MANIFEST

    expect(Puppet::FileSystem.symlink?(link)).to be_falsey
  end
end
