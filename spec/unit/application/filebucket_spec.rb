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
      expect(@filebucket.options).to receive(:[]=).with("#{option}".to_sym, 'arg')
      @filebucket.send("handle_#{option}".to_sym, 'arg')
    end
  end

  describe "during setup" do
    before :each do
      allow(Puppet::Log).to receive(:newdestination)
      allow(Puppet).to receive(:settraps)
      allow(Puppet::FileBucket::Dipper).to receive(:new)
      allow(@filebucket.options).to receive(:[])
    end

    it "should set console as the log destination" do
      expect(Puppet::Log).to receive(:newdestination).with(:console)

      @filebucket.setup
    end

    it "should trap INT" do
      expect(Signal).to receive(:trap).with(:INT)

      @filebucket.setup
    end

    it "should set log level to debug if --debug was passed" do
      allow(@filebucket.options).to receive(:[]).with(:debug).and_return(true)
      @filebucket.setup
      expect(Puppet::Log.level).to eq(:debug)
    end

    it "should set log level to info if --verbose was passed" do
      allow(@filebucket.options).to receive(:[]).with(:verbose).and_return(true)
      @filebucket.setup
      expect(Puppet::Log.level).to eq(:info)
    end

    it "should print puppet config if asked to in Puppet config" do
      allow(Puppet.settings).to receive(:print_configs?).and_return(true)
      expect(Puppet.settings).to receive(:print_configs).and_return(true)
      expect { @filebucket.setup }.to exit_with 0
    end

    it "should exit after printing puppet config if asked to in Puppet config" do
      allow(Puppet.settings).to receive(:print_configs?).and_return(true)
      expect { @filebucket.setup }.to exit_with 1
    end

    describe "with local bucket" do
      let(:path) { File.expand_path("path") }

      before :each do
        allow(@filebucket.options).to receive(:[]).with(:local).and_return(true)
      end

      it "should create a client with the default bucket if none passed" do
        Puppet[:clientbucketdir] = path
        Puppet[:bucketdir] = path + "2"

        expect(Puppet::FileBucket::Dipper).to receive(:new).with(hash_including(Path: path))

        @filebucket.setup
      end

      it "should create a local Dipper with the given bucket" do
        allow(@filebucket.options).to receive(:[]).with(:bucket).and_return(path)

        expect(Puppet::FileBucket::Dipper).to receive(:new).with(hash_including(Path: path))

        @filebucket.setup
      end
    end

    describe "with remote bucket" do
      it "should create a remote Client to the configured server" do
        Puppet[:server] = "puppet.reductivelabs.com"
        expect(Puppet::FileBucket::Dipper).to receive(:new).with(hash_including(Server: "puppet.reductivelabs.com"))
        @filebucket.setup
      end

      it "should default to the first server_list entry if set" do
        Puppet[:server_list] = "foo,bar,baz"
        expect(Puppet::FileBucket::Dipper).to receive(:new).with(hash_including(Server: "foo"))
        @filebucket.setup
      end

      it "should fall back to server if server_list is empty" do
        Puppet[:server_list] = ""
        expect(Puppet::FileBucket::Dipper).to receive(:new).with(hash_including(Server: "puppet"))
        @filebucket.setup
      end

      it "should take both the server and port specified in server_list" do
        Puppet[:server_list] = "foo:632,bar:6215,baz:351"
        expect(Puppet::FileBucket::Dipper).to receive(:new).with({ :Server => "foo", :Port => "632" })
        @filebucket.setup
      end
    end
  end

  describe "when running" do
    before :each do
      allow(Puppet::Log).to receive(:newdestination)
      allow(Puppet).to receive(:settraps)
      allow(Puppet::FileBucket::Dipper).to receive(:new)
      allow(@filebucket.options).to receive(:[])

      @client = double('client')
      allow(Puppet::FileBucket::Dipper).to receive(:new).and_return(@client)

      @filebucket.setup
    end

    it "should use the first non-option parameter as the dispatch" do
      allow(@filebucket.command_line).to receive(:args).and_return(['get'])

      expect(@filebucket).to receive(:get)

      @filebucket.run_command
    end

    describe "the command get" do
      before :each do
        allow(@filebucket).to receive(:print)
        allow(@filebucket).to receive(:args).and_return([])
      end

      it "should call the client getfile method" do
        expect(@client).to receive(:getfile)

        @filebucket.get
      end

      it "should call the client getfile method with the given md5" do
        md5="DEADBEEF"
        allow(@filebucket).to receive(:args).and_return([md5])

        expect(@client).to receive(:getfile).with(md5)

        @filebucket.get
      end

      it "should print the file content" do
        allow(@client).to receive(:getfile).and_return("content")

        expect(@filebucket).to receive(:print).and_return("content")

        @filebucket.get
      end
    end

    describe "the command backup" do
      it "should fail if no arguments are specified" do
        allow(@filebucket).to receive(:args).and_return([])
        expect { @filebucket.backup }.to raise_error(RuntimeError, /You must specify a file to back up/)
      end

      it "should call the client backup method for each given parameter" do
        allow(@filebucket).to receive(:puts)
        allow(Puppet::FileSystem).to receive(:exist?).and_return(true)
        allow(FileTest).to receive(:readable?).and_return(true)
        allow(@filebucket).to receive(:args).and_return(["file1", "file2"])

        expect(@client).to receive(:backup).with("file1")
        expect(@client).to receive(:backup).with("file2")

        @filebucket.backup
      end
    end

    describe "the command restore" do
      it "should call the client getfile method with the given md5" do
        md5="DEADBEEF"
        file="testfile"
        allow(@filebucket).to receive(:args).and_return([file, md5])

        expect(@client).to receive(:restore).with(file,md5)

        @filebucket.restore
      end
    end

    describe "the command diff" do
      it "should call the client diff method with 2 given checksums" do
        md5a="DEADBEEF"
        md5b="BEEF"
        allow(Puppet::FileSystem).to receive(:exist?).and_return(false)
        allow(@filebucket).to receive(:args).and_return([md5a, md5b])

        expect(@client).to receive(:diff).with(md5a,md5b, nil, nil)

        @filebucket.diff
      end

      it "should call the clien diff with a path if the second argument is a file" do
        md5a="DEADBEEF"
        md5b="BEEF"
        allow(Puppet::FileSystem).to receive(:exist?).with(md5a).and_return(false)
        allow(Puppet::FileSystem).to receive(:exist?).with(md5b).and_return(true)
        allow(@filebucket).to receive(:args).and_return([md5a, md5b])

        expect(@client).to receive(:diff).with(md5a, nil, nil, md5b)

        @filebucket.diff
      end

      it "should call the clien diff with a path if the first argument is a file" do
        md5a="DEADBEEF"
        md5b="BEEF"
        allow(Puppet::FileSystem).to receive(:exist?).with(md5a).and_return(true)
        allow(Puppet::FileSystem).to receive(:exist?).with(md5b).and_return(false)
        allow(@filebucket).to receive(:args).and_return([md5a, md5b])

        expect(@client).to receive(:diff).with(nil, md5b, md5a, nil)

        @filebucket.diff
      end

      it "should call the clien diff with paths if the both arguments are files" do
        md5a="DEADBEEF"
        md5b="BEEF"
        allow(Puppet::FileSystem).to receive(:exist?).with(md5a).and_return(true)
        allow(Puppet::FileSystem).to receive(:exist?).with(md5b).and_return(true)
        allow(@filebucket).to receive(:args).and_return([md5a, md5b])

        expect(@client).to receive(:diff).with(nil, nil, md5a, md5b)

        @filebucket.diff
      end

      it "should fail if only one checksum is given" do
        md5a="DEADBEEF"
        allow(@filebucket).to receive(:args).and_return([md5a])

        expect { @filebucket.diff }.to raise_error Puppet::Error
      end
    end

    describe "the command list" do
      it "should call the client list method with nil dates" do
        expect(@client).to receive(:list).with(nil, nil)

        @filebucket.list
      end

      it "should call the client list method with the given dates" do
        # 3 Hours ago
        threehours = 60*60*3
        fromdate = (Time.now - threehours).strftime("%F %T")
        # 1 Hour ago
        onehour = 60*60
        todate = (Time.now - onehour).strftime("%F %T")

        allow(@filebucket.options).to receive(:[]).with(:fromdate).and_return(fromdate)
        allow(@filebucket.options).to receive(:[]).with(:todate).and_return(todate)

        expect(@client).to receive(:list).with(fromdate, todate)

        @filebucket.list
      end
    end
  end
end
