#! /usr/bin/env ruby
require 'spec_helper'
require 'puppet_spec/files'
require 'puppet/indirector/indirector_testing/json'

describe Puppet::Indirector::JSON do
  include PuppetSpec::Files

  subject { Puppet::IndirectorTesting::JSON.new }
  let :model       do Puppet::IndirectorTesting end
  let :indirection do model.indirection end

  context "#path" do
    before :each do
      Puppet[:server_datadir] = '/sample/datadir/master'
      Puppet[:client_datadir] = '/sample/datadir/client'
    end

    it "uses the :server_datadir setting if this is the master" do
      Puppet.run_mode.stubs(:master?).returns(true)
      expected = File.join(Puppet[:server_datadir], 'indirector_testing', 'testing.json')
      subject.path('testing').should == expected
    end

    it "uses the :client_datadir setting if this is not the master" do
      Puppet.run_mode.stubs(:master?).returns(false)
      expected = File.join(Puppet[:client_datadir], 'indirector_testing', 'testing.json')
      subject.path('testing').should == expected
    end

    it "overrides the default extension with a supplied value" do
      Puppet.run_mode.stubs(:master?).returns(true)
      expected = File.join(Puppet[:server_datadir], 'indirector_testing', 'testing.not-json')
      subject.path('testing', '.not-json').should == expected
    end

    ['../foo', '..\\foo', './../foo', '.\\..\\foo',
     '/foo', '//foo', '\\foo', '\\\\goo',
     "test\0/../bar", "test\0\\..\\bar",
     "..\\/bar", "/tmp/bar", "/tmp\\bar", "tmp\\bar",
     " / bar", " /../ bar", " \\..\\ bar",
     "c:\\foo", "c:/foo", "\\\\?\\UNC\\bar", "\\\\foo\\bar",
     "\\\\?\\c:\\foo", "//?/UNC/bar", "//foo/bar",
     "//?/c:/foo",
    ].each do |input|
      it "should resist directory traversal attacks (#{input.inspect})" do
        expect { subject.path(input) }.to raise_error ArgumentError, 'invalid key'
      end
    end
  end

  context "handling requests" do
    before :each do
      Puppet.run_mode.stubs(:master?).returns(true)
      Puppet[:server_datadir] = tmpdir('jsondir')
      FileUtils.mkdir_p(File.join(Puppet[:server_datadir], 'indirector_testing'))
    end

    let :file do subject.path(request.key) end

    def with_content(text)
      FileUtils.mkdir_p(File.dirname(file))
      File.open(file, 'w') {|f| f.puts text }
      yield if block_given?
    end

    it "data saves and then loads again correctly" do
      subject.save(indirection.request(:save, 'example', model.new('banana')))
      subject.find(indirection.request(:find, 'example', nil)).value.should == 'banana'
    end

    context "#find" do
      let :request do indirection.request(:find, 'example', nil) end

      it "returns nil if the file doesn't exist" do
        subject.find(request).should be_nil
      end

      it "raises a descriptive error when the file can't be read" do
        with_content(model.new('foo').to_pson) do
          # I don't like this, but there isn't a credible alternative that
          # also works on Windows, so a stub it is. At least the expectation
          # will fail if the implementation changes. Sorry to the next dev.
          File.expects(:read).with(file).raises(Errno::EPERM)
          expect { subject.find(request) }.
            to raise_error Puppet::Error, /Could not read JSON/
        end
      end

      it "raises a descriptive error when the file content is invalid" do
        with_content("this is totally invalid JSON") do
          expect { subject.find(request) }.
            to raise_error Puppet::Error, /Could not parse JSON data/
        end
      end

      it "should return an instance of the indirected object when valid" do
        with_content(model.new(1).to_pson) do
          instance = subject.find(request)
          instance.should be_an_instance_of model
          instance.value.should == 1
        end
      end
    end

    context "#save" do
      let :instance do model.new(4) end
      let :request  do indirection.request(:find, 'example', instance) end

      it "should save the instance of the request as JSON to disk" do
        subject.save(request)
        content = File.read(file)
        content.should =~ /"document_type"\s*:\s*"IndirectorTesting"/
        content.should =~ /"value"\s*:\s*4/
      end

      it "should create the indirection directory if required" do
        target = File.join(Puppet[:server_datadir], 'indirector_testing')
        Dir.rmdir(target)

        subject.save(request)

        File.should be_directory(target)
      end
    end

    context "#destroy" do
      let :request do indirection.request(:find, 'example', nil) end

      it "removes an existing file" do
        with_content('hello') do
          subject.destroy(request)
        end
        Puppet::FileSystem.exist?(file).should be_false
      end

      it "silently succeeds when files don't exist" do
        Puppet::FileSystem.unlink(file) rescue nil
        subject.destroy(request).should be_true
      end

      it "raises an informative error for other failures" do
        Puppet::FileSystem.stubs(:unlink).with(file).raises(Errno::EPERM, 'fake permission problem')
        with_content('hello') do
          expect { subject.destroy(request) }.to raise_error(Puppet::Error)
        end
        Puppet::FileSystem.unstub(:unlink)    # thanks, mocha
      end
    end
  end

  context "#search" do
    before :each do
      Puppet.run_mode.stubs(:master?).returns(true)
      Puppet[:server_datadir] = tmpdir('jsondir')
      FileUtils.mkdir_p(File.join(Puppet[:server_datadir], 'indirector_testing'))
    end

    def request(glob)
      indirection.request(:search, glob, nil)
    end

    def create_file(name, value = 12)
      File.open(subject.path(name, ''), 'w') do |f|
        f.puts Puppet::IndirectorTesting.new(value).to_pson
      end
    end

    it "returns an empty array when nothing matches the key as a glob" do
      subject.search(request('*')).should == []
    end

    it "returns an array with one item if one item matches" do
      create_file('foo.json', 'foo')
      create_file('bar.json', 'bar')
      subject.search(request('f*')).map(&:value).should == ['foo']
    end

    it "returns an array of items when more than one item matches" do
      create_file('foo.json', 'foo')
      create_file('bar.json', 'bar')
      create_file('baz.json', 'baz')
      subject.search(request('b*')).map(&:value).should =~ ['bar', 'baz']
    end

    it "only items with the .json extension" do
      create_file('foo.json', 'foo-json')
      create_file('foo.pson', 'foo-pson')
      create_file('foo.json~', 'foo-backup')
      subject.search(request('f*')).map(&:value).should == ['foo-json']
    end
  end
end
