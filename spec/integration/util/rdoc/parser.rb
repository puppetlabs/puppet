#!/usr/bin/env ruby

Dir.chdir(File.dirname(__FILE__)) { (s = lambda { |f| File.exist?(f) ? require(f) : Dir.chdir("..") { s.call(f) } }).call("spec/spec_helper.rb") }

require 'puppet/parser/loaded_code'
require 'puppet/util/rdoc/parser'
require 'puppet/util/rdoc'
require 'puppet/util/rdoc/code_objects'
require 'rdoc/options'
require 'rdoc/rdoc'

describe RDoc::Parser do
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

    it "should parse to RDoc data structure" do
        @parser.expects(:document_class).with { |n,k,c| n == "::test" and k.is_a?(Puppet::Parser::ResourceType) }
        @parser.scan
    end
end
