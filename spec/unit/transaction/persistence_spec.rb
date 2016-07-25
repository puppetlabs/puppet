#! /usr/bin/env ruby
require 'spec_helper'

require 'yaml'
require 'fileutils'
require 'puppet/transaction/persistence'

describe Puppet::Transaction::Persistence do
  include PuppetSpec::Files

  before(:each) do
    @basepath = File.expand_path("/somepath")
  end

  describe "when loading from file" do
    before do
      Puppet.settings.stubs(:use).returns(true)
    end

    describe "when the file/directory does not exist" do
      before(:each) do
        @path = tmpfile('storage_test')
      end

      it "should not fail to load" do
        expect(Puppet::FileSystem.exist?(@path)).to be_falsey
        Puppet[:statedir] = @path
        persistence = Puppet::Transaction::Persistence.new
        persistence.load
        Puppet[:transactionstorefile] = @path
        persistence = Puppet::Transaction::Persistence.new
        persistence.load
      end

      it "should not lose its internal state when load is called" do
        expect(Puppet::FileSystem.exist?(@path)).to be_falsey

        persistence = Puppet::Transaction::Persistence.new
        persistence.resources = {"a"=>"b"}
        expect(persistence.resources).to eq({"a"=>"b"})

        Puppet[:transactionstorefile] = @path
        persistence.load
        expect(persistence.resources).to eq({"a"=>"b"})
      end
    end

    describe "when the file/directory exists" do
      before(:each) do
        @tmpfile = tmpfile('storage_test')
        FileUtils.touch(@tmpfile)
        Puppet[:transactionstorefile] = @tmpfile
      end

      def write_state_file(contents)
        File.open(@tmpfile, 'w') { |f| f.write(contents) }
      end

      it "should overwrite its internal state if load() is called" do
        persistence = Puppet::Transaction::Persistence.new
        persistence.resources = {"a"=>"b"}
        expect(persistence.resources).to eq({"a"=>"b"})

        persistence.load

        expect(persistence.resources).to eq({"a"=>"b"})
      end

      it "should restore its internal state if the file contains valid YAML" do
        test_yaml = {"resources"=>{"a"=>"b"}}
        write_state_file(test_yaml.to_yaml)

        persistence = Puppet::Transaction::Persistence.new
        persistence.load

        expect(persistence.data).to eq(test_yaml)
      end

      it "should initialize with a clear internal state if the file does not contain valid YAML" do
        write_state_file('{ invalid')

        persistence = Puppet::Transaction::Persistence.new
        persistence.load

        expect(persistence.data).to eq({"resources"=>{}})
      end

      it "should initialize with a clear internal state if the file does not contain a hash of data" do
        write_state_file("not_a_hash")

        persistence = Puppet::Transaction::Persistence.new
        persistence.load

        expect(persistence.data).to eq({"resources"=>{}})
      end

      it "should raise an error if the file does not contain valid YAML and cannot be renamed" do
        write_state_file('{ invalid')

        File.expects(:rename).raises(SystemCallError)

        persistence = Puppet::Transaction::Persistence.new
        expect { persistence.load }.to raise_error(Puppet::Error, /Could not rename/)
      end

      it "should attempt to rename the file if the file is corrupted" do
        write_state_file('{ invalid')

        File.expects(:rename).at_least_once

        persistence = Puppet::Transaction::Persistence.new
        persistence.load
      end

      it "should fail gracefully on load() if the file is not a regular file" do
        FileUtils.rm_f(@tmpfile)
        Dir.mkdir(@tmpfile)

        persistence = Puppet::Transaction::Persistence.new
        persistence.load
      end
    end
  end

  describe "when storing to the file" do
    before(:each) do
      @tmpfile = tmpfile('persistence_test')
      @saved = Puppet[:transactionstorefile]
      Puppet[:transactionstorefile] = @tmpfile
    end

    it "should create the file if it does not exist" do
      expect(Puppet::FileSystem.exist?(Puppet[:transactionstorefile])).to be_falsey

      persistence = Puppet::Transaction::Persistence.new
      persistence.resources = {"a"=>"b"}
      persistence.save

      expect(Puppet::FileSystem.exist?(Puppet[:transactionstorefile])).to be_truthy
    end

    it "should raise an exception if the file is not a regular file" do
      Dir.mkdir(Puppet[:transactionstorefile])
      persistence = Puppet::Transaction::Persistence.new
      persistence.resources = {"a"=>"b"}

      if Puppet.features.microsoft_windows?
        expect { persistence.save }.to raise_error(Puppet::Util::Windows::Error, /Access is denied/)
      else
        expect { persistence.save }.to raise_error(Errno::EISDIR, /Is a directory/)
      end

      Dir.rmdir(Puppet[:transactionstorefile])
    end

    it "should load the same information that it saves" do
      persistence = Puppet::Transaction::Persistence.new
      persistence.resources = {"a"=>"b"}
      expect(persistence.resources).to eq({"a"=>"b"})

      persistence.save
      persistence.load

      expect(persistence.resources).to eq({"a"=>"b"})
    end
  end
end
