#! /usr/bin/env ruby
require 'spec_helper'

require 'yaml'
require 'fileutils'
require 'puppet/util/storage'

describe Puppet::Util::Storage do
  include PuppetSpec::Files

  before(:each) do
    @basepath = File.expand_path("/somepath")
  end

  describe "when caching a symbol" do
    it "should return an empty hash" do
      expect(Puppet::Util::Storage.cache(:yayness)).to eq({})
      expect(Puppet::Util::Storage.cache(:more_yayness)).to eq({})
    end

    it "should add the symbol to its internal state" do
      Puppet::Util::Storage.cache(:yayness)
      expect(Puppet::Util::Storage.state).to eq({:yayness=>{}})
    end

    it "should not clobber existing state when caching additional objects" do
      Puppet::Util::Storage.cache(:yayness)
      expect(Puppet::Util::Storage.state).to eq({:yayness=>{}})
      Puppet::Util::Storage.cache(:bubblyness)
      expect(Puppet::Util::Storage.state).to eq({:yayness=>{},:bubblyness=>{}})
    end
  end

  describe "when caching a Puppet::Type" do
    before(:each) do
      @file_test = Puppet::Type.type(:file).new(:name => @basepath+"/yayness", :audit => %w{checksum type})
      @exec_test = Puppet::Type.type(:exec).new(:name => @basepath+"/bin/ls /yayness")
    end

    it "should return an empty hash" do
      expect(Puppet::Util::Storage.cache(@file_test)).to eq({})
      expect(Puppet::Util::Storage.cache(@exec_test)).to eq({})
    end

    it "should add the resource ref to its internal state" do
      expect(Puppet::Util::Storage.state).to eq({})
      Puppet::Util::Storage.cache(@file_test)
      expect(Puppet::Util::Storage.state).to eq({"File[#{@basepath}/yayness]"=>{}})
      Puppet::Util::Storage.cache(@exec_test)
      expect(Puppet::Util::Storage.state).to eq({"File[#{@basepath}/yayness]"=>{}, "Exec[#{@basepath}/bin/ls /yayness]"=>{}})
    end
  end

  describe "when caching something other than a resource or symbol" do
    it "should cache by converting to a string" do
      data = Puppet::Util::Storage.cache(42)
      data[:yay] = true
      expect(Puppet::Util::Storage.cache("42")[:yay]).to be_truthy
    end
  end

  it "should clear its internal state when clear() is called" do
    Puppet::Util::Storage.cache(:yayness)
    expect(Puppet::Util::Storage.state).to eq({:yayness=>{}})
    Puppet::Util::Storage.clear
    expect(Puppet::Util::Storage.state).to eq({})
  end

  describe "when loading from the state file" do
    before do
      Puppet.settings.stubs(:use).returns(true)
    end

    describe "when the state file/directory does not exist" do
      before(:each) do
        @path = tmpfile('storage_test')
      end

      it "should not fail to load" do
        expect(Puppet::FileSystem.exist?(@path)).to be_falsey
        Puppet[:statedir] = @path
        Puppet::Util::Storage.load
        Puppet[:statefile] = @path
        Puppet::Util::Storage.load
      end

      it "should not lose its internal state when load() is called" do
        expect(Puppet::FileSystem.exist?(@path)).to be_falsey

        Puppet::Util::Storage.cache(:yayness)
        expect(Puppet::Util::Storage.state).to eq({:yayness=>{}})

        Puppet[:statefile] = @path
        Puppet::Util::Storage.load

        expect(Puppet::Util::Storage.state).to eq({:yayness=>{}})
      end
    end

    describe "when the state file/directory exists" do
      before(:each) do
        @state_file = tmpfile('storage_test')
        FileUtils.touch(@state_file)
        Puppet[:statefile] = @state_file
      end

      def write_state_file(contents)
        File.open(@state_file, 'w') { |f| f.write(contents) }
      end

      it "should overwrite its internal state if load() is called" do
        # Should the state be overwritten even if Puppet[:statefile] is not valid YAML?
        Puppet::Util::Storage.cache(:yayness)
        expect(Puppet::Util::Storage.state).to eq({:yayness=>{}})

        Puppet::Util::Storage.load

        expect(Puppet::Util::Storage.state).to eq({})
      end

      it "should restore its internal state if the state file contains valid YAML" do
        test_yaml = {'File["/yayness"]'=>{"name"=>{:a=>:b,:c=>:d}}}
        write_state_file(test_yaml.to_yaml)

        Puppet::Util::Storage.load

        expect(Puppet::Util::Storage.state).to eq(test_yaml)
      end

      it "should initialize with a clear internal state if the state file does not contain valid YAML" do
        write_state_file('{ invalid')

        Puppet::Util::Storage.load

        expect(Puppet::Util::Storage.state).to eq({})
      end

      it "should initialize with a clear internal state if the state file does not contain a hash of data" do
        write_state_file("not_a_hash")

        Puppet::Util::Storage.load

        expect(Puppet::Util::Storage.state).to eq({})
      end

      it "should raise an error if the state file does not contain valid YAML and cannot be renamed" do
        write_state_file('{ invalid')

        File.expects(:rename).raises(SystemCallError)

        expect { Puppet::Util::Storage.load }.to raise_error(Puppet::Error, /Could not rename/)
      end

      it "should attempt to rename the state file if the file is corrupted" do
        write_state_file('{ invalid')

        File.expects(:rename).at_least_once

        Puppet::Util::Storage.load
      end

      it "should fail gracefully on load() if the state file is not a regular file" do
        FileUtils.rm_f(@state_file)
        Dir.mkdir(@state_file)

        Puppet::Util::Storage.load
      end
    end
  end

  describe "when storing to the state file" do
    before(:each) do
      @state_file = tmpfile('storage_test')
      @saved_statefile = Puppet[:statefile]
      Puppet[:statefile] = @state_file
    end

    it "should create the state file if it does not exist" do
      expect(Puppet::FileSystem.exist?(Puppet[:statefile])).to be_falsey
      Puppet::Util::Storage.cache(:yayness)

      Puppet::Util::Storage.store

      expect(Puppet::FileSystem.exist?(Puppet[:statefile])).to be_truthy
    end

    it "should raise an exception if the state file is not a regular file" do
      Dir.mkdir(Puppet[:statefile])
      Puppet::Util::Storage.cache(:yayness)

      if Puppet.features.microsoft_windows?
        expect { Puppet::Util::Storage.store }.to raise_error do |error|
          expect(error).to be_a(Puppet::Util::Windows::Error)
          expect(error.code).to eq(5) # ERROR_ACCESS_DENIED
        end
      else
        expect { Puppet::Util::Storage.store }.to raise_error(Errno::EISDIR, /Is a directory/)
      end

      Dir.rmdir(Puppet[:statefile])
    end

    it "should load() the same information that it store()s" do
      Puppet::Util::Storage.cache(:yayness)
      expect(Puppet::Util::Storage.state).to eq({:yayness=>{}})

      Puppet::Util::Storage.store
      Puppet::Util::Storage.clear

      expect(Puppet::Util::Storage.state).to eq({})

      Puppet::Util::Storage.load

      expect(Puppet::Util::Storage.state).to eq({:yayness=>{}})
    end
  end
end
