require 'spec_helper'

require 'puppet/util/filetype'

# XXX Import all of the tests into this file.
describe Puppet::Util::FileType do
  describe "the flat filetype" do
    let(:path) { '/my/file' }
    let(:type) { Puppet::Util::FileType.filetype(:flat) }
    let(:file) { type.new(path) }

    it "should exist" do
      expect(type).not_to be_nil
    end

    describe "when the file already exists" do
      it "should return the file's contents when asked to read it" do
        expect(Puppet::FileSystem).to receive(:exist?).with(path).and_return(true)
        expect(Puppet::FileSystem).to receive(:read).with(path, {:encoding => Encoding.default_external}).and_return("my text")

        expect(file.read).to eq("my text")
      end

      it "should unlink the file when asked to remove it" do
        expect(Puppet::FileSystem).to receive(:exist?).with(path).and_return(true)
        expect(Puppet::FileSystem).to receive(:unlink).with(path)

        file.remove
      end
    end

    describe "when the file does not exist" do
      it "should return an empty string when asked to read the file" do
        expect(Puppet::FileSystem).to receive(:exist?).with(path).and_return(false)

        expect(file.read).to eq("")
      end
    end

    describe "when writing the file" do
      let(:tempfile) { double('tempfile', :print => nil, :close => nil, :flush => nil, :path => "/other/file") }

      before do
        allow(FileUtils).to receive(:cp)
        allow(Tempfile).to receive(:new).and_return(tempfile)
      end

      it "should first create a temp file and copy its contents over to the file location" do
        expect(Tempfile).to receive(:new).with("puppet", {:encoding => Encoding.default_external}).and_return(tempfile)
        expect(tempfile).to receive(:print).with("my text")
        expect(tempfile).to receive(:flush)
        expect(tempfile).to receive(:close)
        expect(FileUtils).to receive(:cp).with(tempfile.path, path)

        file.write "my text"
      end

      it "should set the selinux default context on the file" do
        expect(file).to receive(:set_selinux_default_context).with(path)
        file.write "eh"
      end
    end

    describe "when backing up a file" do
      it "should do nothing if the file does not exist" do
        expect(Puppet::FileSystem).to receive(:exist?).with(path).and_return(false)
        expect(file).not_to receive(:bucket)
        file.backup
      end

      it "should use its filebucket to backup the file if it exists" do
        expect(Puppet::FileSystem).to receive(:exist?).with(path).and_return(true)

        bucket = double('bucket')
        expect(bucket).to receive(:backup).with(path)

        expect(file).to receive(:bucket).and_return(bucket)
        file.backup
      end

      it "should use the default filebucket" do
        bucket = double('bucket')
        expect(bucket).to receive(:bucket).and_return("mybucket")

        expect(Puppet::Type.type(:filebucket)).to receive(:mkdefaultbucket).and_return(bucket)

        expect(file.bucket).to eq("mybucket")
      end
    end
  end

  shared_examples_for "crontab provider" do
    let(:cron)         { type.new('no_such_user') }
    let(:crontab)      { File.read(my_fixture(crontab_output)) }
    let(:options)      { { :failonfail => true, :combine => true } }
    let(:uid)          { 'no_such_user' }
    let(:user_options) { options.merge({:uid => uid}) }

    it "should exist" do
      expect(type).not_to be_nil
    end

    # make Puppet::Util::SUIDManager return something deterministic, not the
    # uid of the user running the tests, except where overridden below.
    before :each do
      allow(Puppet::Util::SUIDManager).to receive(:uid).and_return(1234)
    end

    describe "#read" do
      before(:each) do
        allow(Puppet::Util).to receive(:uid).with(uid).and_return(9000)
      end

      it "should run crontab -l as the target user" do
        expect(Puppet::Util::Execution).to receive(:execute)
          .with(['crontab', '-l'], user_options)
          .and_return(Puppet::Util::Execution::ProcessOutput.new(crontab, 0))
        expect(cron.read).to eq(crontab)
      end

      it "should not switch user if current user is the target user" do
        expect(Puppet::Util).to receive(:uid).with(uid).twice.and_return(9000)
        expect(Puppet::Util::SUIDManager).to receive(:uid).and_return(9000)
        expect(Puppet::Util::Execution).to receive(:execute)
          .with(['crontab', '-l'], options)
          .and_return(Puppet::Util::Execution::ProcessOutput.new(crontab, 0))
        expect(cron.read).to eq(crontab)
      end

      it "should treat an absent crontab as empty" do
        expect(Puppet::Util::Execution).to receive(:execute).with(['crontab', '-l'], user_options).and_raise(Puppet::ExecutionFailure, absent_crontab)
        expect(cron.read).to eq('')
      end

      it "should treat a nonexistent user's crontab as empty" do
        expect(Puppet::Util).to receive(:uid).with(uid).and_return(nil)

        expect(cron.read).to eq('')
      end

      it "should return empty if the user is not authorized to use cron" do
        expect(Puppet::Util::Execution).to receive(:execute).with(['crontab', '-l'], user_options).and_raise(Puppet::ExecutionFailure, unauthorized_crontab)
        expect(cron.read).to eq('')
      end
    end

    describe "#remove" do
      it "should run crontab -r as the target user" do
        expect(Puppet::Util::Execution).to receive(:execute).with(['crontab', '-r'], user_options)
        cron.remove
      end

      it "should not switch user if current user is the target user" do
        expect(Puppet::Util).to receive(:uid).with(uid).and_return(9000)
        expect(Puppet::Util::SUIDManager).to receive(:uid).and_return(9000)
        expect(Puppet::Util::Execution).to receive(:execute).with(['crontab','-r'], options)
        cron.remove
      end
    end

    describe "#write" do
      before :each do
        @tmp_cron = Tempfile.new("puppet_crontab_spec")
        @tmp_cron_path = @tmp_cron.path
        allow(Puppet::Util).to receive(:uid).with(uid).and_return(9000)
        expect(Tempfile).to receive(:new).with("puppet_#{name}", {:encoding => Encoding.default_external}).and_return(@tmp_cron)
      end

      after :each do
        expect(Puppet::FileSystem.exist?(@tmp_cron_path)).to be_falsey
      end

      it "should run crontab as the target user on a temporary file" do
        expect(File).to receive(:chown).with(9000, nil, @tmp_cron_path)
        expect(Puppet::Util::Execution).to receive(:execute).with(["crontab", @tmp_cron_path], user_options)

        expect(@tmp_cron).to receive(:print).with("foo\n")
        cron.write "foo\n"
      end

      it "should not switch user if current user is the target user" do
        expect(Puppet::Util::SUIDManager).to receive(:uid).and_return(9000)
        expect(File).to receive(:chown).with(9000, nil, @tmp_cron_path)
        expect(Puppet::Util::Execution).to receive(:execute).with(["crontab", @tmp_cron_path], options)

        expect(@tmp_cron).to receive(:print).with("foo\n")
        cron.write "foo\n"
      end
    end
  end

  describe "the suntab filetype", :unless => Puppet::Util::Platform.windows? do
    let(:type)           { Puppet::Util::FileType.filetype(:suntab) }
    let(:name)           { type.name }
    let(:crontab_output) { 'suntab_output' }

    # possible crontab output was taken from here:
    # https://docs.oracle.com/cd/E19082-01/819-2380/sysrescron-60/index.html
    let(:absent_crontab) do
      'crontab: can\'t open your crontab file'
    end
    let(:unauthorized_crontab) do
      'crontab: you are not authorized to use cron. Sorry.'
    end

    it_should_behave_like "crontab provider"
  end

  describe "the aixtab filetype", :unless => Puppet::Util::Platform.windows? do
    let(:type)           { Puppet::Util::FileType.filetype(:aixtab) }
    let(:name)           { type.name }
    let(:crontab_output) { 'aixtab_output' }

    let(:absent_crontab) do
      '0481-103 Cannot open a file in the /var/spool/cron/crontabs directory.'
    end
    let(:unauthorized_crontab) do
      '0481-109 You are not authorized to use the cron command.'
    end

    it_should_behave_like "crontab provider"
  end
end
