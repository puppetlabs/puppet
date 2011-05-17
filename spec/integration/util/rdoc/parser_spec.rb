#!/usr/bin/env rspec
require 'spec_helper'

require 'puppet/resource/type_collection'
require 'puppet/util/rdoc/parser'
require 'puppet/util/rdoc'
require 'puppet/util/rdoc/code_objects'
require 'rdoc/options'
require 'rdoc/rdoc'

describe RDoc::Parser, :'fails_on_ruby_1.9.2' => true do
  require 'puppet_spec/files'
  include PuppetSpec::Files

  before :each do
    tmpdir = tmpfile('rdoc_parser_tmp')
    Dir.mkdir(tmpdir)
    @parsedfile = File.join(tmpdir, 'init.pp')

    File.open(@parsedfile, 'w') do |f|
      f.puts '# comment'
      f.puts 'class ::test {}'
    end

    @top_level = stub_everything 'toplevel', :file_relative_name => @parsedfile
    @module = stub_everything 'module'
    @puppet_top_level = RDoc::PuppetTopLevel.new(@top_level)
    RDoc::PuppetTopLevel.stubs(:new).returns(@puppet_top_level)
    @puppet_top_level.expects(:add_module).returns(@module)
    @parser = RDoc::Parser.new(@top_level, @parsedfile, nil, Options.instance, RDoc::Stats.new)
  end

  after(:each) do
    File.unlink(@parsedfile)
  end

  def get_test_class(toplevel)
    # toplevel -> main -> test
    toplevel.classes[0].classes[0]
  end

  it "should parse to RDoc data structure" do
    @parser.expects(:document_class).with { |n,k,c| n == "::test" and k.is_a?(Puppet::Resource::Type) }
    @parser.scan
  end

  it "should get a PuppetClass for the main class" do
    @parser.scan.classes[0].should be_a(RDoc::PuppetClass)
  end

  it "should produce a PuppetClass whose name is test" do
    get_test_class(@parser.scan).name.should == "test"
  end

  it "should produce a PuppetClass whose comment is 'comment'" do
    get_test_class(@parser.scan).comment.should == "comment\n"
  end
end
