#!/usr/bin/env rspec
require 'spec_helper'

require 'puppet/ssl/inventory'

describe Puppet::SSL::Inventory, :unless => Puppet.features.microsoft_windows? do
  before do
    @class = Puppet::SSL::Inventory
  end

  it "should use the :certinventory setting for the path to the inventory file" do
    Puppet.settings.expects(:value).with(:cert_inventory).returns "/inven/tory"

    @class.any_instance.stubs(:rebuild)

    @class.new.path.should == "/inven/tory"
  end

  describe "when initializing" do
    it "should set its path to the inventory file" do
      Puppet.settings.stubs(:value).with(:cert_inventory).returns "/inven/tory"
      @class.new.path.should == "/inven/tory"
    end
  end

  describe "when managing an inventory" do
    before do
      Puppet.settings.stubs(:value).with(:cert_inventory).returns "/inven/tory"

      FileTest.stubs(:exist?).with("/inven/tory").returns true

      @inventory = @class.new

      @cert = mock 'cert'
    end

    describe "and creating the inventory file" do
      before do
        Puppet.settings.stubs(:write)
        FileTest.stubs(:exist?).with("/inven/tory").returns false

        Puppet::SSL::Certificate.indirection.stubs(:search).returns []
      end

      it "should log that it is building a new inventory file" do
        Puppet.expects(:notice)

        @inventory.rebuild
      end

      it "should use the Settings to write to the file" do
        Puppet.settings.expects(:write).with(:cert_inventory)

        @inventory.rebuild
      end

      it "should add a header to the file" do
        fh = mock 'filehandle'
        Puppet.settings.stubs(:write).yields fh
        fh.expects(:print).with { |str| str =~ /^#/ }

        @inventory.rebuild
      end

      it "should add formatted information on all existing certificates" do
        cert1 = mock 'cert1'
        cert2 = mock 'cert2'

        Puppet::SSL::Certificate.indirection.expects(:search).with("*").returns [cert1, cert2]

        @class.any_instance.expects(:add).with(cert1)
        @class.any_instance.expects(:add).with(cert2)

        @inventory.rebuild
      end
    end

    describe "and adding a certificate" do
      it "should build the inventory file if one does not exist" do
        Puppet.settings.stubs(:value).with(:cert_inventory).returns "/inven/tory"
        Puppet.settings.stubs(:write)

        FileTest.expects(:exist?).with("/inven/tory").returns false

        @inventory.expects(:rebuild)

        @inventory.add(@cert)
      end

      it "should use the Settings to write to the file" do
        Puppet.settings.expects(:write).with(:cert_inventory, "a")

        @inventory.add(@cert)
      end

      it "should use the actual certificate if it was passed a Puppet certificate" do
        cert = Puppet::SSL::Certificate.new("mycert")
        cert.content = @cert

        fh = stub 'filehandle', :print => nil
        Puppet.settings.stubs(:write).yields fh

        @inventory.expects(:format).with(@cert)

        @inventory.add(@cert)
      end

      it "should add formatted certificate information to the end of the file" do
        fh = mock 'filehandle'

        Puppet.settings.stubs(:write).yields fh

        @inventory.expects(:format).with(@cert).returns "myformat"

        fh.expects(:print).with("myformat")

        @inventory.add(@cert)
      end
    end

    describe "and formatting a certificate", :fails_on_windows => true do
      before do
        @cert = stub 'cert', :not_before => Time.now, :not_after => Time.now, :subject => "mycert", :serial => 15
      end

      it "should print the serial number as a 4 digit hex number in the first field" do
        @inventory.format(@cert).split[0].should == "0x000f" # 15 in hex
      end

      it "should print the not_before date in '%Y-%m-%dT%H:%M:%S%Z' format in the second field" do
        @cert.not_before.expects(:strftime).with('%Y-%m-%dT%H:%M:%S%Z').returns "before_time"

        @inventory.format(@cert).split[1].should == "before_time"
      end

      it "should print the not_after date in '%Y-%m-%dT%H:%M:%S%Z' format in the third field" do
        @cert.not_after.expects(:strftime).with('%Y-%m-%dT%H:%M:%S%Z').returns "after_time"

        @inventory.format(@cert).split[2].should == "after_time"
      end

      it "should print the subject in the fourth field" do
        @inventory.format(@cert).split[3].should == "mycert"
      end

      it "should add a carriage return" do
        @inventory.format(@cert).should =~ /\n$/
      end

      it "should produce a line consisting of the serial number, start date, expiration date, and subject" do
        # Just make sure our serial and subject bracket the lines.
        @inventory.format(@cert).should =~ /^0x.+mycert$/
      end
    end

    it "should be able to find a given host's serial number" do
      @inventory.should respond_to(:serial)
    end

    describe "and finding a serial number" do
      it "should return nil if the inventory file is missing" do
        FileTest.expects(:exist?).with("/inven/tory").returns false
        @inventory.serial(:whatever).should be_nil
      end

      it "should return the serial number from the line matching the provided name" do
        File.expects(:readlines).with("/inven/tory").returns ["0x00f blah blah /CN=me\n", "0x001 blah blah /CN=you\n"]

        @inventory.serial("me").should == 15
      end

      it "should return the number as an integer" do
        File.expects(:readlines).with("/inven/tory").returns ["0x00f blah blah /CN=me\n", "0x001 blah blah /CN=you\n"]

        @inventory.serial("me").should == 15
      end
    end
  end
end
