#! /usr/bin/env ruby
require 'spec_helper'

require 'puppet/application/filebucket'
require 'puppet/file_bucket/dipper'

describe Puppet::Application::Filebucket do
  before :each do
    @filebucket = Puppet::Application[:filebucket]
  end

  it "should declare a get command" do
    expect(@filebucket).to respond_to(:get)
  end

  it "should declare a backup command" do
    expect(@filebucket).to respond_to(:backup)
  end

  it "should declare a restore command" do
    expect(@filebucket).to respond_to(:restore)
  end

  it "should declare a diff command" do
    expect(@filebucket).to respond_to(:diff)
  end

  it "should declare a list command" do
    expect(@filebucket).to respond_to(:list)
  end

  [:bucket, :debug, :local, :remote, :verbose, :fromdate, :todate].each do |option|
    it "should declare handle_#{option} method" do
      expect(@filebucket).to respond_to("handle_#{option}".to_sym)
    end

    it "should store argument value when calling handle_#{option}" do
      @filebucket.options.expects(:[]=).with("#{option}".to_sym, 'arg')
      @filebucket.send("handle_#{option}".to_sym, 'arg')
    end
  end

  describe "during setup" do

    before :each do
      Puppet::Log.stubs(:newdestination)
      Puppet.stubs(:settraps)
      Puppet::FileBucket::Dipper.stubs(:new)
      @filebucket.options.stubs(:[]).with(any_parameters)
    end


    it "should set console as the log destination" do
      Puppet::Log.expects(:newdestination).with(:console)

      @filebucket.setup
    end

    it "should trap INT" do
      Signal.expects(:trap).with(:INT)

      @filebucket.setup
    end

    it "should set log level to debug if --debug was passed" do
      @filebucket.options.stubs(:[]).with(:debug).returns(true)
      @filebucket.setup
      expect(Puppet::Log.level).to eq(:debug)
    end

    it "should set log level to info if --verbose was passed" do
      @filebucket.options.stubs(:[]).with(:verbose).returns(true)
      @filebucket.setup
      expect(Puppet::Log.level).to eq(:info)
    end

    it "should print puppet config if asked to in Puppet config" do
      Puppet.settings.stubs(:print_configs?).returns(true)
      Puppet.settings.expects(:print_configs).returns(true)
      expect { @filebucket.setup }.to exit_with 0
    end

    it "should exit after printing puppet config if asked to in Puppet config" do
      Puppet.settings.stubs(:print_configs?).returns(true)
      expect { @filebucket.setup }.to exit_with 1
    end

    describe "with local bucket" do
      let(:path) { File.expand_path("path") }

      before :each do
        @filebucket.options.stubs(:[]).with(:local).returns(true)
      end

      it "should create a client with the default bucket if none passed" do
        Puppet[:bucketdir] = path

        Puppet::FileBucket::Dipper.expects(:new).with { |h| h[:Path] == path }

        @filebucket.setup
      end

      it "should create a local Dipper with the given bucket" do
        @filebucket.options.stubs(:[]).with(:bucket).returns(path)

        Puppet::FileBucket::Dipper.expects(:new).with { |h| h[:Path] == path }

        @filebucket.setup
      end

    end

    describe "with remote bucket" do

      it "should create a remote Client to the configured server" do
        Puppet[:server] = "puppet.reductivelabs.com"

        Puppet::FileBucket::Dipper.expects(:new).with { |h| h[:Server] == "puppet.reductivelabs.com" }

        @filebucket.setup
      end

    end

  end

  describe "when running" do

    before :each do
      Puppet::Log.stubs(:newdestination)
      Puppet.stubs(:settraps)
      Puppet::FileBucket::Dipper.stubs(:new)
      @filebucket.options.stubs(:[]).with(any_parameters)

      @client = stub 'client'
      Puppet::FileBucket::Dipper.stubs(:new).returns(@client)

      @filebucket.setup
    end

    it "should use the first non-option parameter as the dispatch" do
      @filebucket.command_line.stubs(:args).returns(['get'])

      @filebucket.expects(:get)

      @filebucket.run_command
    end

    describe "the command get" do

      before :each do
        @filebucket.stubs(:print)
        @filebucket.stubs(:args).returns([])
      end

      it "should call the client getfile method" do
        @client.expects(:getfile)

        @filebucket.get
      end

      it "should call the client getfile method with the given md5" do
        md5="DEADBEEF"
        @filebucket.stubs(:args).returns([md5])

        @client.expects(:getfile).with(md5)

        @filebucket.get
      end

      it "should print the file content" do
        @client.stubs(:getfile).returns("content")

        @filebucket.expects(:print).returns("content")

        @filebucket.get
      end

    end

    describe "the command backup" do
      it "should fail if no arguments are specified" do
        @filebucket.stubs(:args).returns([])
        expect { @filebucket.backup }.to raise_error(RuntimeError, /You must specify a file to back up/)
      end

      it "should call the client backup method for each given parameter" do
        @filebucket.stubs(:puts)
        Puppet::FileSystem.stubs(:exist?).returns(true)
        FileTest.stubs(:readable?).returns(true)
        @filebucket.stubs(:args).returns(["file1", "file2"])

        @client.expects(:backup).with("file1")
        @client.expects(:backup).with("file2")

        @filebucket.backup
      end
    end

    describe "the command restore" do
      it "should call the client getfile method with the given md5" do
        md5="DEADBEEF"
        file="testfile"
        @filebucket.stubs(:args).returns([file, md5])

        @client.expects(:restore).with(file,md5)

        @filebucket.restore
      end
    end

    describe "the command diff" do
      it "should call the client diff method with 2 given checksums" do
        md5a="DEADBEEF"
        md5b="BEEF"
        Puppet::FileSystem.stubs(:exist?).returns(false)
        @filebucket.stubs(:args).returns([md5a, md5b])

        @client.expects(:diff).with(md5a,md5b, nil, nil)

        @filebucket.diff
      end

      it "should call the clien diff with a path if the second argument is a file" do
        md5a="DEADBEEF"
        md5b="BEEF"
        Puppet::FileSystem.stubs(:exist?).with(md5a).returns(false)
        Puppet::FileSystem.stubs(:exist?).with(md5b).returns(true)
        @filebucket.stubs(:args).returns([md5a, md5b])

        @client.expects(:diff).with(md5a, nil, nil, md5b)

        @filebucket.diff
      end

      it "should call the clien diff with a path if the first argument is a file" do
        md5a="DEADBEEF"
        md5b="BEEF"
        Puppet::FileSystem.stubs(:exist?).with(md5a).returns(true)
        Puppet::FileSystem.stubs(:exist?).with(md5b).returns(false)
        @filebucket.stubs(:args).returns([md5a, md5b])

        @client.expects(:diff).with(nil, md5b, md5a, nil)

        @filebucket.diff
      end

      it "should call the clien diff with paths if the both arguments are files" do
        md5a="DEADBEEF"
        md5b="BEEF"
        Puppet::FileSystem.stubs(:exist?).with(md5a).returns(true)
        Puppet::FileSystem.stubs(:exist?).with(md5b).returns(true)
        @filebucket.stubs(:args).returns([md5a, md5b])

        @client.expects(:diff).with(nil, nil, md5a, md5b)

        @filebucket.diff
      end

      it "should fail if only one checksum is given" do
        md5a="DEADBEEF"
        @filebucket.stubs(:args).returns([md5a])

        expect { @filebucket.diff }.to raise_error Puppet::Error
      end
    end
    describe "the command list" do
      it "should call the client list method with nil dates" do
        @client.expects(:list).with(nil, nil)

        @filebucket.list
      end
      it "should call the client list method with the given dates" do
        # 3 Hours ago
        threehours = 60*60*3
        fromdate = (Time.now - threehours).strftime("%F %T")
        # 1 Hour ago
        onehour = 60*60
        todate = (Time.now - onehour).strftime("%F %T")

        @filebucket.options.stubs(:[]).with(:fromdate).returns(fromdate)
        @filebucket.options.stubs(:[]).with(:todate).returns(todate)

        @client.expects(:list).with(fromdate, todate)

        @filebucket.list
      end
    end

  end


end
