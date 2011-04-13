#!/usr/bin/env rspec
#
#  Created by Luke Kanies on 2008-3-10.
#  Copyright (c) 2007. All rights reserved.

require 'spec_helper'

require 'puppet/indirector/ssl_file'

describe Puppet::Indirector::SslFile do
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
    @path = "/tmp/my_directory"
    Puppet[:noop] = false
    Puppet[@setting] = @path
    Puppet[:trace] = false
  end

  it "should use :main and :ssl upon initialization" do
    Puppet.settings.expects(:use).with(:main, :ssl)
    @file_class.new
  end

  it "should return a nil collection directory if no directory setting has been provided" do
    @file_class.store_in nil
    @file_class.collection_directory.should be_nil
  end

  it "should return a nil file location if no location has been provided" do
    @file_class.store_at nil
    @file_class.file_location.should be_nil
  end

  it "should fail if no store directory or file location has been set" do
    @file_class.store_in nil
    @file_class.store_at nil
    lambda { @file_class.new }.should raise_error(Puppet::DevError)
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
      @searcher.should be_ca("amaca")
    end

    describe "when choosing the location for certificates" do
      it "should set them at the ca setting's path if a ca setting is available and the name resolves to the CA name" do
        @file_class.store_in nil
        @file_class.store_at :mysetting
        @file_class.store_ca_at :casetting

        Puppet.settings.stubs(:value).with(:casetting).returns "/ca/file"

        @searcher.expects(:ca?).with(@cert.name).returns true
        @searcher.path(@cert.name).should == "/ca/file"
      end

      it "should set them at the file location if a file setting is available" do
        @file_class.store_in nil
        @file_class.store_at :mysetting

        Puppet.settings.stubs(:value).with(:mysetting).returns "/some/file"

        @searcher.path(@cert.name).should == "/some/file"
      end

      it "should set them in the setting directory, with the certificate name plus '.pem', if a directory setting is available" do
        @searcher.path(@cert.name).should == @certpath
      end
    end

    describe "when finding certificates on disk" do
      describe "and no certificate is present" do
        before do
          # Stub things so the case management bits work.
          FileTest.stubs(:exist?).with(File.dirname(@certpath)).returns false
          FileTest.expects(:exist?).with(@certpath).returns false
        end

        it "should return nil" do
          @searcher.find(@request).should be_nil
        end
      end

      describe "and a certificate is present" do
        before do
          FileTest.expects(:exist?).with(@certpath).returns true
        end

        it "should return an instance of the model, which it should use to read the certificate" do
          cert = mock 'cert'
          model = mock 'model'
          @file_class.stubs(:model).returns model

          model.expects(:new).with("myname").returns cert
          cert.expects(:read).with(@certpath)
          @searcher.find(@request).should equal(cert)
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
          FileTest.expects(:exist?).with(@path).returns(false)
          dir, file = File.split(@path)
          FileTest.expects(:exist?).with(dir).returns true
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
        lambda { @searcher.save(@request) }.should raise_error(Puppet::Error)
      end

      it "should fail if the directory is not writeable" do
        FileTest.stubs(:directory?).returns true
        FileTest.expects(:writable?).with(File.dirname(@certpath)).returns false
        lambda { @searcher.save(@request) }.should raise_error(Puppet::Error)
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
          Puppet.settings.expects(:writesub).with(@setting, @certpath).yields fh

          @searcher.save(@request)
        end
      end

      describe "and a file location is set" do
        it "should use the filehandle provided by the Settings" do
          @searcher.class.store_at @setting

          fh = mock 'filehandle'
          fh.stubs :print
          Puppet.settings.expects(:write).with(@setting).yields fh
          @searcher.save(@request)
        end
      end

      describe "and the name is the CA name and a ca setting is set" do
        it "should use the filehandle provided by the Settings" do
          @searcher.class.store_at @setting
          @searcher.class.store_ca_at :castuff
          Puppet.settings.stubs(:value).with(:castuff).returns "castuff stub"

          fh = mock 'filehandle'
          fh.stubs :print
          Puppet.settings.expects(:write).with(:castuff).yields fh
          @searcher.stubs(:ca?).returns true
          @searcher.save(@request)
        end
      end
    end

    describe "when destroying certificates" do
      describe "that do not exist" do
        before do
          FileTest.expects(:exist?).with(@certpath).returns false
        end

        it "should return false" do
          @searcher.destroy(@request).should be_false
        end
      end

      describe "that exist" do
        before do
          FileTest.expects(:exist?).with(@certpath).returns true
        end

        it "should unlink the certificate file" do
          File.expects(:unlink).with(@certpath)
          @searcher.destroy(@request)
        end

        it "should log that is removing the file" do
          File.stubs(:exist?).returns true
          File.stubs(:unlink)
          Puppet.expects(:notice)
          @searcher.destroy(@request)
        end
      end
    end

    describe "when searching for certificates" do
      before do
        @model = mock 'model'
        @file_class.stubs(:model).returns @model
      end
      it "should return a certificate instance for all files that exist" do
        Dir.expects(:entries).with(@path).returns %w{one.pem two.pem}

        one = stub 'one', :read => nil
        two = stub 'two', :read => nil

        @model.expects(:new).with("one").returns one
        @model.expects(:new).with("two").returns two

        @searcher.search(@request).should == [one, two]
      end

      it "should read each certificate in using the model's :read method" do
        Dir.expects(:entries).with(@path).returns %w{one.pem}

        one = stub 'one'
        one.expects(:read).with(File.join(@path, "one.pem"))

        @model.expects(:new).with("one").returns one

        @searcher.search(@request)
      end

      it "should skip any files that do not match /\.pem$/" do
        Dir.expects(:entries).with(@path).returns %w{. .. one.pem}

        one = stub 'one', :read => nil

        @model.expects(:new).with("one").returns one

        @searcher.search(@request)
      end
    end
  end
end
