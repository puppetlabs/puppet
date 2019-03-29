require 'spec_helper'

require 'puppet/indirector/ssl_file'

describe Puppet::Indirector::SslFile do
  include PuppetSpec::Files

  before(:all) do
    class Puppet::SslTestModel
      extend Puppet::Indirector
      indirects :ssl_test_model
    end

    class Puppet::SslTestModel::SslFile < Puppet::Indirector::SslFile
    end

    Puppet::SslTestModel.indirection.terminus_class = :ssl_file
  end

  after(:all) do
    Puppet::SslTestModel.indirection.delete
    Puppet.send(:remove_const, :SslTestModel)
  end

  let(:terminus_class) { Puppet::SslTestModel::SslFile }
  let(:model) { Puppet::SslTestModel }

  before :each do
    @setting = :certdir
    terminus_class.store_in @setting
    terminus_class.store_at nil
    @path = make_absolute("/thisdoesntexist/my_directory")
    Puppet[:noop] = false
    Puppet[@setting] = @path
    Puppet[:trace] = false
  end

  after :each do
    terminus_class.store_in nil
    terminus_class.store_at nil
  end

  it "should use :main and :ssl upon initialization" do
    expect(Puppet.settings).to receive(:use).with(:main, :ssl)
    terminus_class.new
  end

  it "should return a nil collection directory if no directory setting has been provided" do
    terminus_class.store_in nil
    expect(terminus_class.collection_directory).to be_nil
  end

  it "should return a nil file location if no location has been provided" do
    terminus_class.store_at nil
    expect(terminus_class.file_location).to be_nil
  end

  it "should fail if no store directory or file location has been set" do
    expect(Puppet.settings).to receive(:use).with(:main, :ssl)
    terminus_class.store_in nil
    terminus_class.store_at nil
    expect {
      terminus_class.new
    }.to raise_error(Puppet::DevError, /No file or directory setting provided/)
  end

  describe "when managing ssl files" do
    before do
      allow(Puppet.settings).to receive(:use)
      @searcher = terminus_class.new

      @cert = double('certificate', :name => "myname")
      @certpath = File.join(@path, "myname.pem")

      @request = double('request', :key => @cert.name, :instance => @cert)
    end

    describe "when choosing the location for certificates" do
      it "should set them at the file location if a file setting is available" do
        terminus_class.store_in nil
        terminus_class.store_at :hostcrl

        Puppet[:hostcrl] = File.expand_path("/some/file")

        expect(@searcher.path(@cert.name)).to eq(Puppet[:hostcrl])
      end

      it "should set them in the setting directory, with the certificate name plus '.pem', if a directory setting is available" do
        expect(@searcher.path(@cert.name)).to eq(@certpath)
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
          expect { @searcher.path(input) }.to raise_error(ArgumentError, /invalid key/)
        end
      end

      # REVISIT: Should probably test MS-DOS reserved names here, too, since
      # they would represent a vulnerability on a Win32 system, should we ever
      # support that path.  Don't forget that 'CON.foo' == 'CON'
      # --daniel 2011-09-24
    end

    describe "when finding certificates on disk" do
      describe "and no certificate is present" do
        it "should return nil" do
          expect(Puppet::FileSystem).to receive(:exist?).with(@path).and_return(true)
          expect(Dir).to receive(:entries).with(@path).and_return([])
          expect(Puppet::FileSystem).to receive(:exist?).with(@certpath).and_return(false)

          expect(@searcher.find(@request)).to be_nil
        end
      end

      describe "and a certificate is present" do
        let(:cert) { double('cert') }
        let(:model) { double('model') }

        before(:each) do
          allow(terminus_class).to receive(:model).and_return(model)
        end

        context "is readable" do
          it "should return an instance of the model, which it should use to read the certificate" do
            expect(Puppet::FileSystem).to receive(:exist?).with(@certpath).and_return(true)

            expect(model).to receive(:new).with("myname").and_return(cert)
            expect(cert).to receive(:read).with(@certpath)

            expect(@searcher.find(@request)).to equal(cert)
          end
        end

        context "is unreadable" do
          it "should raise an exception" do
            expect(Puppet::FileSystem).to receive(:exist?).with(@certpath).and_return(true)

            expect(model).to receive(:new).with("myname").and_return(cert)
            expect(cert).to receive(:read).with(@certpath).and_raise(Errno::EACCES)

            expect {
              @searcher.find(@request)
            }.to raise_error(Errno::EACCES)
          end
        end
      end

      describe "and a certificate is present but has uppercase letters" do
        before do
          @request = double('request', :key => "myhost")
        end

        # This is kind of more an integration test; it's for #1382, until
        # the support for upper-case certs can be removed around mid-2009.
        it "should rename the existing file to the lower-case path" do
          @path = @searcher.path("myhost")
          expect(Puppet::FileSystem).to receive(:exist?).with(@path).and_return(false)
          dir, file = File.split(@path)
          expect(Puppet::FileSystem).to receive(:exist?).with(dir).and_return(true)
          expect(Dir).to receive(:entries).with(dir).and_return([".", "..", "something.pem", file.upcase])

          expect(File).to receive(:rename).with(File.join(dir, file.upcase), @path)

          cert = double('cert')
          model = double('model')
          allow(@searcher).to receive(:model).and_return(model)
          expect(@searcher.model).to receive(:new).with("myhost").and_return(cert)
          expect(cert).to receive(:read).with(@path)

          @searcher.find(@request)
        end
      end
    end

    describe "when saving certificates to disk" do
      before do
        allow(FileTest).to receive(:directory?).and_return(true)
        allow(FileTest).to receive(:writable?).and_return(true)
      end

      it "should fail if the directory is absent" do
        expect(FileTest).to receive(:directory?).with(File.dirname(@certpath)).and_return(false)
        expect { @searcher.save(@request) }.to raise_error(Puppet::Error)
      end

      it "should fail if the directory is not writeable" do
        allow(FileTest).to receive(:directory?).and_return(true)
        expect(FileTest).to receive(:writable?).with(File.dirname(@certpath)).and_return(false)
        expect { @searcher.save(@request) }.to raise_error(Puppet::Error)
      end

      it "should save to the path the output of converting the certificate to a string" do
        fh = double('filehandle')
        expect(fh).to receive(:print).with("mycert")

        allow(@searcher).to receive(:write).and_yield(fh)
        expect(@cert).to receive(:to_s).and_return("mycert")

        @searcher.save(@request)
      end

      describe "and a directory setting is set" do
        it "should use the Settings class to write the file" do
          @searcher.class.store_in @setting
          fh = double('filehandle')
          allow(fh).to receive(:print)
          expect(Puppet.settings.setting(@setting)).to receive(:open_file).with(@certpath, 'w:ASCII').and_yield(fh)

          @searcher.save(@request)
        end
      end

      describe "and a file location is set" do
        it "should use the filehandle provided by the Settings" do
          @searcher.class.store_at @setting

          fh = double('filehandle')
          allow(fh).to receive(:print)
          expect(Puppet.settings.setting(@setting)).to receive(:open).with('w:ASCII').and_yield(fh)
          @searcher.save(@request)
        end
      end
    end

    describe "when destroying certificates" do
      describe "that do not exist" do
        before do
          expect(Puppet::FileSystem).to receive(:exist?).with(Puppet::FileSystem.pathname(@certpath)).and_return(false)
        end

        it "should return false" do
          expect(@searcher.destroy(@request)).to be_falsey
        end
      end

      describe "that exist" do
        it "should unlink the certificate file" do
          path = Puppet::FileSystem.pathname(@certpath)
          expect(Puppet::FileSystem).to receive(:exist?).with(path).and_return(true)
          expect(Puppet::FileSystem).to receive(:unlink).with(path)
          @searcher.destroy(@request)
        end

        it "should log that is removing the file" do
          allow(Puppet::FileSystem).to receive(:exist?).and_return(true)
          allow(Puppet::FileSystem).to receive(:unlink)
          expect(Puppet).to receive(:notice)
          @searcher.destroy(@request)
        end
      end
    end

    describe "when searching for certificates" do
      let(:one) { double('one') }
      let(:two) { double('two') }
      let(:one_path) { File.join(@path, 'one.pem') }
      let(:two_path) { File.join(@path, 'two.pem') }
      let(:model) { double('model') }

      before :each do
        allow(terminus_class).to receive(:model).and_return(model)
      end

      it "should return a certificate instance for all files that exist" do
        expect(Dir).to receive(:entries).with(@path).and_return(%w{. .. one.pem two.pem})

        expect(model).to receive(:new).with("one").and_return(one)
        expect(one).to receive(:read).with(one_path)
        expect(model).to receive(:new).with("two").and_return(two)
        expect(two).to receive(:read).with(two_path)

        expect(@searcher.search(@request)).to eq([one, two])
      end

      it "should raise an exception if any file is unreadable" do
        expect(Dir).to receive(:entries).with(@path).and_return(%w{. .. one.pem two.pem})

        expect(model).to receive(:new).with("one").and_return(one)
        expect(one).to receive(:read).with(one_path)
        expect(model).to receive(:new).with("two").and_return(two)
        expect(two).to receive(:read).and_raise(Errno::EACCES)

        expect {
          @searcher.search(@request)
        }.to raise_error(Errno::EACCES)
      end

      it "should skip any files that do not match /\.pem$/" do
        expect(Dir).to receive(:entries).with(@path).and_return(%w{. .. one two.notpem})

        expect(model).not_to receive(:new)

        expect(@searcher.search(@request)).to eq([])
      end
    end
  end
end
