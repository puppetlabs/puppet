#! /usr/bin/env ruby
require 'spec_helper'

require 'puppet/indirector/ssl_file'

describe Puppet::Indirector::SslFile do
  include PuppetSpec::Files

  before :all do
    @indirection = stub 'indirection', :name => :testing, :model => @model
    Puppet::Indirector::Indirection.expects(:instance).with(:testing).returns(@indirection)
    module Testing; end
    @file_class = class Testing::MyType < Puppet::Indirector::SslFile
      self
    end
  end
  before :each do
    @model = mock 'model'

    @setting = :certdir
    @file_class.store_in @setting
    @file_class.store_at nil
    @file_class.store_ca_at nil
    @path = make_absolute("/thisdoesntexist/my_directory")
    Puppet[:noop] = false
    Puppet[@setting] = @path
    Puppet[:trace] = false
  end

  after :each do
    @file_class.store_in nil
    @file_class.store_at nil
    @file_class.store_ca_at nil
  end

  it "should use :main and :ssl upon initialization" do
    Puppet.settings.expects(:use).with(:main, :ssl)
    @file_class.new
  end

  it "should return a nil collection directory if no directory setting has been provided" do
    @file_class.store_in nil
    expect(@file_class.collection_directory).to be_nil
  end

  it "should return a nil file location if no location has been provided" do
    @file_class.store_at nil
    expect(@file_class.file_location).to be_nil
  end

  it "should fail if no store directory or file location has been set" do
    Puppet.settings.expects(:use).with(:main, :ssl)
    @file_class.store_in nil
    @file_class.store_at nil
    expect {
      @file_class.new
    }.to raise_error(Puppet::DevError, /No file or directory setting provided/)
  end

  describe "when managing ssl files" do
    before do
      Puppet.settings.stubs(:use)
      @searcher = @file_class.new

      @cert = stub 'certificate', :name => "myname"
      @certpath = File.join(@path, "myname.pem")

      @request = stub 'request', :key => @cert.name, :instance => @cert
    end

    it "should consider the file a ca file if the name is equal to what the SSL::Host class says is the CA name" do
      Puppet::SSL::Host.expects(:ca_name).returns "amaca"
      expect(@searcher).to be_ca("amaca")
    end

    describe "when choosing the location for certificates" do
      it "should set them at the ca setting's path if a ca setting is available and the name resolves to the CA name" do
        @file_class.store_in nil
        @file_class.store_at :mysetting
        @file_class.store_ca_at :cakey

        Puppet[:cakey] = File.expand_path("/ca/file")

        @searcher.expects(:ca?).with(@cert.name).returns true
        expect(@searcher.path(@cert.name)).to eq(Puppet[:cakey])
      end

      it "should set them at the file location if a file setting is available" do
        @file_class.store_in nil
        @file_class.store_at :cacrl

        Puppet[:cacrl] = File.expand_path("/some/file")

        expect(@searcher.path(@cert.name)).to eq(Puppet[:cacrl])
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
          Puppet::FileSystem.expects(:exist?).with(@path).returns(true)
          Dir.expects(:entries).with(@path).returns([])
          Puppet::FileSystem.expects(:exist?).with(@certpath).returns(false)

          expect(@searcher.find(@request)).to be_nil
        end
      end

      describe "and a certificate is present" do
        let(:cert) { mock 'cert' }
        let(:model) { mock 'model' }

        before(:each) do
          @file_class.stubs(:model).returns model
        end

        context "is readable" do
          it "should return an instance of the model, which it should use to read the certificate" do
            Puppet::FileSystem.expects(:exist?).with(@certpath).returns true

            model.expects(:new).with("myname").returns cert
            cert.expects(:read).with(@certpath)

            expect(@searcher.find(@request)).to equal(cert)
          end
        end

        context "is unreadable" do
          it "should raise an exception" do
            Puppet::FileSystem.expects(:exist?).with(@certpath).returns(true)

            model.expects(:new).with("myname").returns cert
            cert.expects(:read).with(@certpath).raises(Errno::EACCES)

            expect {
              @searcher.find(@request)
            }.to raise_error(Errno::EACCES)
          end
        end
      end

      describe "and a certificate is present but has uppercase letters" do
        before do
          @request = stub 'request', :key => "myhost"
        end

        # This is kind of more an integration test; it's for #1382, until
        # the support for upper-case certs can be removed around mid-2009.
        it "should rename the existing file to the lower-case path" do
          @path = @searcher.path("myhost")
          Puppet::FileSystem.expects(:exist?).with(@path).returns(false)
          dir, file = File.split(@path)
          Puppet::FileSystem.expects(:exist?).with(dir).returns true
          Dir.expects(:entries).with(dir).returns [".", "..", "something.pem", file.upcase]

          File.expects(:rename).with(File.join(dir, file.upcase), @path)

          cert = mock 'cert'
          model = mock 'model'
          @searcher.stubs(:model).returns model
          @searcher.model.expects(:new).with("myhost").returns cert
          cert.expects(:read).with(@path)

          @searcher.find(@request)
        end
      end
    end

    describe "when saving certificates to disk" do
      before do
        FileTest.stubs(:directory?).returns true
        FileTest.stubs(:writable?).returns true
      end

      it "should fail if the directory is absent" do
        FileTest.expects(:directory?).with(File.dirname(@certpath)).returns false
        expect { @searcher.save(@request) }.to raise_error(Puppet::Error)
      end

      it "should fail if the directory is not writeable" do
        FileTest.stubs(:directory?).returns true
        FileTest.expects(:writable?).with(File.dirname(@certpath)).returns false
        expect { @searcher.save(@request) }.to raise_error(Puppet::Error)
      end

      it "should save to the path the output of converting the certificate to a string" do
        fh = mock 'filehandle'
        fh.expects(:print).with("mycert")

        @searcher.stubs(:write).yields fh
        @cert.expects(:to_s).returns "mycert"

        @searcher.save(@request)
      end

      describe "and a directory setting is set" do
        it "should use the Settings class to write the file" do
          @searcher.class.store_in @setting
          fh = mock 'filehandle'
          fh.stubs :print
          Puppet.settings.setting(@setting).expects(:open_file).with(@certpath, 'w').yields fh

          @searcher.save(@request)
        end
      end

      describe "and a file location is set" do
        it "should use the filehandle provided by the Settings" do
          @searcher.class.store_at @setting

          fh = mock 'filehandle'
          fh.stubs :print
          Puppet.settings.setting(@setting).expects(:open).with('w').yields fh
          @searcher.save(@request)
        end
      end

      describe "and the name is the CA name and a ca setting is set" do
        it "should use the filehandle provided by the Settings" do
          @searcher.class.store_at @setting
          @searcher.class.store_ca_at :cakey
          Puppet[:cakey] = "castuff stub"

          fh = mock 'filehandle'
          fh.stubs :print
          Puppet.settings.setting(:cakey).expects(:open).with('w').yields fh
          @searcher.stubs(:ca?).returns true
          @searcher.save(@request)
        end
      end
    end

    describe "when destroying certificates" do
      describe "that do not exist" do
        before do
          Puppet::FileSystem.expects(:exist?).with(Puppet::FileSystem.pathname(@certpath)).returns false
        end

        it "should return false" do
          expect(@searcher.destroy(@request)).to be_falsey
        end
      end

      describe "that exist" do
        it "should unlink the certificate file" do
          path = Puppet::FileSystem.pathname(@certpath)
          Puppet::FileSystem.expects(:exist?).with(path).returns true
          Puppet::FileSystem.expects(:unlink).with(path)
          @searcher.destroy(@request)
        end

        it "should log that is removing the file" do
          Puppet::FileSystem.stubs(:exist?).returns true
          Puppet::FileSystem.stubs(:unlink)
          Puppet.expects(:notice)
          @searcher.destroy(@request)
        end
      end
    end

    describe "when searching for certificates" do
      let(:one) { stub 'one' }
      let(:two) { stub 'two' }
      let(:one_path) { File.join(@path, 'one.pem') }
      let(:two_path) { File.join(@path, 'two.pem') }
      let(:model) { mock 'model' }

      before :each do
        @file_class.stubs(:model).returns model
      end

      it "should return a certificate instance for all files that exist" do
        Dir.expects(:entries).with(@path).returns(%w{. .. one.pem two.pem})

        model.expects(:new).with("one").returns one
        one.expects(:read).with(one_path)
        model.expects(:new).with("two").returns two
        two.expects(:read).with(two_path)

        expect(@searcher.search(@request)).to eq([one, two])
      end

      it "should raise an exception if any file is unreadable" do
        Dir.expects(:entries).with(@path).returns(%w{. .. one.pem two.pem})

        model.expects(:new).with("one").returns(one)
        one.expects(:read).with(one_path)
        model.expects(:new).with("two").returns(two)
        two.expects(:read).raises(Errno::EACCES)

        expect {
          @searcher.search(@request)
        }.to raise_error(Errno::EACCES)
      end

      it "should skip any files that do not match /\.pem$/" do
        Dir.expects(:entries).with(@path).returns(%w{. .. one two.notpem})

        model.expects(:new).never

        expect(@searcher.search(@request)).to eq([])
      end
    end
  end
end
