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
      allow(Puppet.settings).to receive(:use).and_return(true)
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

        expect(Puppet).not_to receive(:err)

        persistence = Puppet::Transaction::Persistence.new
        persistence.set_system_value(resource, property, value)

        persistence.load

        expect(persistence.get_system_value(resource, property)).to eq(nil)
      end

      it "should restore its internal state if the file contains valid YAML" do
        test_yaml = {"resources"=>{"a"=>"b"}}
        write_state_file(test_yaml.to_yaml)

        expect(Puppet).not_to receive(:err)

        persistence = Puppet::Transaction::Persistence.new
        persistence.load

        expect(persistence.data).to eq(test_yaml)
      end

      it "should initialize with a clear internal state if the file does not contain valid YAML" do
        write_state_file('{ invalid')

        expect(Puppet).to receive(:send_log).with(:err, /Transaction store file .* is corrupt/)

        persistence = Puppet::Transaction::Persistence.new
        persistence.load

        expect(persistence.data).to eq({})
      end

      it "should initialize with a clear internal state if the file does not contain a hash of data" do
        write_state_file("not_a_hash")

        expect(Puppet).to receive(:err).with(/Transaction store file .* is valid YAML but not returning a hash/)

        persistence = Puppet::Transaction::Persistence.new
        persistence.load

        expect(persistence.data).to eq({})
      end

      it "should raise an error if the file does not contain valid YAML and cannot be renamed" do
        write_state_file('{ invalid')

        expect(File).to receive(:rename).and_raise(SystemCallError)

        expect(Puppet).to receive(:send_log).with(:err, /Transaction store file .* is corrupt/)
        expect(Puppet).to receive(:send_log).with(:err, /Unable to rename/)

        persistence = Puppet::Transaction::Persistence.new
        expect { persistence.load }.to raise_error(Puppet::Error, /Could not rename/)
      end

      it "should attempt to rename the file if the file is corrupted" do
        write_state_file('{ invalid')

        expect(File).to receive(:rename).at_least(:once)

        expect(Puppet).to receive(:send_log).with(:err, /Transaction store file .* is corrupt/)

        persistence = Puppet::Transaction::Persistence.new
        persistence.load
      end

      it "should fail gracefully on load() if the file is not a regular file" do
        FileUtils.rm_f(@tmpfile)
        Dir.mkdir(@tmpfile)

        expect(Puppet).to receive(:warning).with(/Transaction store file .* is not a file/)

        persistence = Puppet::Transaction::Persistence.new
        persistence.load
      end

      it 'should load Time and Symbols' do
        write_state_file(<<~END)
          File[/tmp/audit]:
            parameters:
              mtime:
                system_value:
                  - 2020-07-15 05:38:12.427678398 +00:00
              ensure:
                system_value:
        END

        persistence = Puppet::Transaction::Persistence.new
        expect(persistence.load.dig("File[/tmp/audit]", "parameters", "mtime", "system_value")).to contain_exactly(be_a(Time))
      end

      it 'should load Regexp' do
        write_state_file(<<~END)
          system_value:
            - !ruby/regexp /regexp/
        END

        persistence = Puppet::Transaction::Persistence.new
        expect(persistence.load.dig("system_value")).to contain_exactly(be_a(Regexp))
      end

      it 'should load semantic puppet version' do
        write_state_file(<<~END)
          system_value:
            - !ruby/object:SemanticPuppet::Version
              major: 1
              minor: 0
              patch: 0
              prerelease: 
              build: 
        END

        persistence = Puppet::Transaction::Persistence.new
        expect(persistence.load.dig("system_value")).to contain_exactly(be_a(SemanticPuppet::Version))
      end

      it 'should load puppet time related objects' do
        write_state_file(<<~END)
          system_value:
            - !ruby/object:Puppet::Pops::Time::Timestamp
              nsecs: 1638316135955087259
            - !ruby/object:Puppet::Pops::Time::TimeData
              nsecs: 1495789430910161286
            - !ruby/object:Puppet::Pops::Time::Timespan
              nsecs: 1495789430910161286
        END

        persistence = Puppet::Transaction::Persistence.new
        expect(persistence.load.dig("system_value")).to contain_exactly(be_a(Puppet::Pops::Time::Timestamp), be_a(Puppet::Pops::Time::TimeData), be_a(Puppet::Pops::Time::Timespan))
      end

      it 'should load binary objects' do
        write_state_file(<<~END)
          system_value:
            - !ruby/object:Puppet::Pops::Types::PBinaryType::Binary
              binary_buffer: ''
        END

        persistence = Puppet::Transaction::Persistence.new
        expect(persistence.load.dig("system_value")).to contain_exactly(be_a(Puppet::Pops::Types::PBinaryType::Binary))
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

      expect { persistence.save }.to raise_error(Errno::EISDIR, /Is a directory/)

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
      double()
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
      allow(mock_catalog).to receive(:host_config?).and_return(true)
      expect(persistence.enabled?(mock_catalog)).to be false
    end

    it "should not be enabled when the catalog is not the host catalog" do
      Puppet.settings.preferred_run_mode = :agent
      allow(mock_catalog).to receive(:host_config?).and_return(false)
      expect(persistence.enabled?(mock_catalog)).to be false
    end

    it "should not be enabled outside of agent mode and the catalog is not the host catalog" do
      Puppet.settings.preferred_run_mode = :user
      allow(mock_catalog).to receive(:host_config?).and_return(false)
      expect(persistence.enabled?(mock_catalog)).to be false
    end

    it "should be enabled in agent mode and when the catalog is the host catalog" do
      Puppet.settings.preferred_run_mode = :agent
      allow(mock_catalog).to receive(:host_config?).and_return(true)
      expect(persistence.enabled?(mock_catalog)).to be true
    end
  end
end
