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
    end

    describe "when the file/directory exists" do
      before(:each) do
        @tmpfile = tmpfile('storage_test')
        Puppet[:transactionstorefile] = @tmpfile
      end

      def write_state_file(contents)
        File.open(@tmpfile, 'w') { |f| f.write(contents) }
      end

      it "should overwrite its internal state if load() is called" do
        resource = "Foo[bar]"
        property = "my"
        value = "something"

        Puppet.expects(:err).never

        persistence = Puppet::Transaction::Persistence.new
        persistence.set_system_value(resource, property, value)

        persistence.load

        expect(persistence.get_system_value(resource, property)).to eq(nil)
      end

      it "should restore its internal state if the file contains valid YAML" do
        test_yaml = {"resources"=>{"a"=>"b"}}
        write_state_file(test_yaml.to_yaml)

        Puppet.expects(:err).never

        persistence = Puppet::Transaction::Persistence.new
        persistence.load

        expect(persistence.data).to eq(test_yaml)
      end

      it "should initialize with a clear internal state if the file does not contain valid YAML" do
        write_state_file('{ invalid')

        Puppet.expects(:err).with(regexp_matches(/Transaction store file .* is corrupt/))

        persistence = Puppet::Transaction::Persistence.new
        persistence.load

        expect(persistence.data).to eq({})
      end

      it "should initialize with a clear internal state if the file does not contain a hash of data" do
        write_state_file("not_a_hash")

        Puppet.expects(:err).with(regexp_matches(/Transaction store file .* is valid YAML but not returning a hash/))

        persistence = Puppet::Transaction::Persistence.new
        persistence.load

        expect(persistence.data).to eq({})
      end

      it "should raise an error if the file does not contain valid YAML and cannot be renamed" do
        write_state_file('{ invalid')

        File.expects(:rename).raises(SystemCallError)

        Puppet.expects(:err).with(regexp_matches(/Transaction store file .* is corrupt/))
        Puppet.expects(:err).with(regexp_matches(/Unable to rename/))

        persistence = Puppet::Transaction::Persistence.new
        expect { persistence.load }.to raise_error(Puppet::Error, /Could not rename/)
      end

      it "should attempt to rename the file if the file is corrupted" do
        write_state_file('{ invalid')

        File.expects(:rename).at_least_once

        Puppet.expects(:err).with(regexp_matches(/Transaction store file .* is corrupt/))

        persistence = Puppet::Transaction::Persistence.new
        persistence.load
      end

      it "should fail gracefully on load() if the file is not a regular file" do
        FileUtils.rm_f(@tmpfile)
        Dir.mkdir(@tmpfile)

        Puppet.expects(:warning).with(regexp_matches(/Transaction store file .* is not a file/))

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
      persistence.save

      expect(Puppet::FileSystem.exist?(Puppet[:transactionstorefile])).to be_truthy
    end

    it "should raise an exception if the file is not a regular file" do
      Dir.mkdir(Puppet[:transactionstorefile])
      persistence = Puppet::Transaction::Persistence.new

      if Puppet.features.microsoft_windows?
        expect do
          persistence.save
        end.to raise_error do |error|
          expect(error).to be_a(Puppet::Util::Windows::Error)
          expect(error.code).to eq(5) # ERROR_ACCESS_DENIED
        end
      else
        expect { persistence.save }.to raise_error(Errno::EISDIR, /Is a directory/)
      end

      Dir.rmdir(Puppet[:transactionstorefile])
    end

    it "should load the same information that it saves" do
      resource = "File[/tmp/foo]"
      property = "content"
      value = "foo"

      persistence = Puppet::Transaction::Persistence.new
      persistence.set_system_value(resource, property, value)

      persistence.save
      persistence.load

      expect(persistence.get_system_value(resource, property)).to eq(value)
    end
  end

  describe "when checking if persistence is enabled" do
    let(:mock_catalog) do
      mock
    end

    let (:persistence) do
      Puppet::Transaction::Persistence.new
    end

    before :all do
      @preferred_run_mode = Puppet.settings.preferred_run_mode
    end

    after :all do
      Puppet.settings.preferred_run_mode = @preferred_run_mode
    end

    it "should not be enabled when not running in agent mode" do
      Puppet.settings.preferred_run_mode = :user
      mock_catalog.stubs(:host_config?).returns(true)
      expect(persistence.enabled?(mock_catalog)).to be false
    end

    it "should not be enabled when the catalog is not the host catalog" do
      Puppet.settings.preferred_run_mode = :agent
      mock_catalog.stubs(:host_config?).returns(false)
      expect(persistence.enabled?(mock_catalog)).to be false
    end

    it "should not be enabled outside of agent mode and the catalog is not the host catalog" do
      Puppet.settings.preferred_run_mode = :user
      mock_catalog.stubs(:host_config?).returns(false)
      expect(persistence.enabled?(mock_catalog)).to be false
    end

    it "should be enabled in agent mode and when the catalog is the host catalog" do
      Puppet.settings.preferred_run_mode = :agent
      mock_catalog.stubs(:host_config?).returns(true)
      expect(persistence.enabled?(mock_catalog)).to be true
    end
  end
end
