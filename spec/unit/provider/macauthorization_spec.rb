#!/usr/bin/env rspec
#
# Unit testing for the macauthorization provider
#

require 'spec_helper'

describe 'macauthorization provider' do
  subject { Puppet::Type.type(:macauthorization).provider(:macauthorization) }
  let(:resource) { subject.new(instance) }
  let(:instance) { mock('new') } 
  let(:authname) { 'foo.boo.mccune' }
  let(:auth_hash) do
    { 'rights' =>
         { 'foo'  =>
            { 'rule' => 'bar'
            }
         },
       'rules' =>
         { 'quux' =>
            { 'group' => 'admin'
            }
         }
      }
  end

  before(:each) do
    subject.stubs(:read_plist).returns(auth_hash)
  end

  it 'should have a create method' do
    resource.should respond_to(:create) 
  end

    it "should have a destroy method" do
    resource.should respond_to(:destroy)
  end

  it "should have an exists? method" do
    resource.should respond_to(:exists?)
  end

  it "should have a flush method" do
    resource.should respond_to(:flush)
  end

  properties = [  :allow_root, :authenticate_user, :auth_class, :comment,
            :group, :k_of_n, :mechanisms, :rule, :session_owner,
            :shared, :timeout, :tries, :auth_type ]

  properties.each do |prop|
    it "should have a #{prop.to_s} method" do
      resource.should respond_to(prop.to_s)
    end

    it "should have a #{prop.to_s}= method" do
      resource.should respond_to(prop.to_s + "=")
    end
  end

  describe "when destroying a right" do
    before :each do
      instance.expects(:[]).with(:auth_type).returns(:right)
    end

    it "should call the internal method destroy_right" do
      resource.expects(:destroy_right)
      resource.destroy
    end
    it "should call the external command 'security authorizationdb remove authname" do
      instance.expects(:[]).with(:name).returns(authname)
      resource.expects(:security).with("authorizationdb", :remove, authname)
      resource.destroy
    end
  end

  describe "when destroying a rule" do
    before :each do
      instance.stubs(:[]).with(:auth_type).returns(:rule)
    end

    it "should call the internal method destroy_rule" do
      resource.expects(:destroy_rule)
      resource.destroy
    end
  end

  describe "when flushing a right" do
    before :each do
      instance.expects(:[]).with(:auth_type).returns(:right)
      #resource.expects(:read_plist).returns({'foorule' => 'foo'})
    end

    it "should call the internal method flush_right" do
      instance.expects(:[]).with(:ensure).returns(:present)
      resource.expects(:flush_right)
      resource.flush
    end

    it "should call the internal method set_right" do
      instance.expects(:[]).with(:ensure).returns(:present)
      instance.expects(:[]).with(:name).times(2).returns(authname)
      Puppet::Util::Execution.expects(:execute).with { |cmds, args|
        cmds.include?("read") and
        cmds.include?(authname) and
        args[:combine] == false
      }.once
      resource.expects(:set_right)
      resource.expects(:read_plist)
      resource.flush
    end

    it "should read and write to the auth database with the right arguments" do
      instance.expects(:[]).with(:ensure).returns(:present)
      instance.expects(:[]).with(:name).times(2).returns(authname)
      Puppet::Util::Execution.expects(:execute).with { |cmds, args|
        cmds.include?("read") and
        cmds.include?(authname) and
        args[:combine] == false
      }.once

      Puppet::Util::Execution.expects(:execute).with { |cmds, args|
        cmds.include?("write") and
        cmds.include?(authname) and
        args[:combine] == false and
        args[:stdinfile] != nil
      }.once
      resource.expects(:read_plist)
      resource.flush
    end
  end

  describe "when flushing a rule" do
    before :each do
      instance.expects(:[]).with(:ensure).returns(:present)
      instance.stubs(:[]).with(:auth_type).returns(:rule)
    end

    it "should call the internal method flush_rule" do
      resource.expects(:flush_rule)
      resource.flush
    end

    it "should call the internal method set_rule" do
      instance.expects(:[]).with(:name).times(2).returns(authname)
      resource.expects(:set_rule)
      resource.expects(:read_plist).returns({'rules' => 'foo'})
      resource.flush
    end
  end
end

describe 'Plist handling behavior in macauthorization' do
  subject { Puppet::Type.type(:macauthorization).provider(:macauthorization) }
  let(:badplist) do
      '<?xml version="1.0" encoding="UTF-8"?>
      <!DOCTYPE plist PUBLIC -//Apple Computer//DTD PLIST 1.0//EN http://www.apple.com/DTDs/PropertyList-1.0.dtd>
      <plist version="1.0">
        <dict>
            <key>test</key>
                <string>file</string>
                  </dict>
                  </plist>'
  end

  let(:goodplist) do
      '<?xml version="1.0" encoding="UTF-8"?>
      <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
      <plist version="1.0">
      <dict>
        <key>test</key>
          <string>file</string>
          </dict>
          </plist>'
  end

  it 'read_plist(): should correct a bad XML doctype string' do
    stubfile = mock('file')
    stubfile.expects(:read).returns(badplist)
    IO.expects(:read).with('plist.file', 8)
    File.expects(:open).returns(stubfile)
    Puppet.expects(:debug).with('Had to fix plist with incorrect DOCTYPE declaration: plist.file')
    subject.read_plist('plist.file')
  end

  it 'read_plist(): should try to create a plist from a file given a binary plist' do
    stubfile = mock('file')
    stubfile.expects(:value)
    IO.expects(:read).with('plist.file', 8).returns('bplist00')
    Puppet::Util::CFPropertyList::List.expects(:new).with(:file => 'plist.file').returns(stubfile)
    Puppet.expects(:debug).never
    subject.read_plist('plist.file')
  end

  it 'read_plist(): should fail when trying to read invalid XML' do
    stubfile = mock('file')
    stubfile.expects(:read).returns('<bad}|%-->xml<--->')
    IO.expects(:read).with('plist.file', 8)
    File.expects(:open).returns(stubfile)
    # Even though we rescue the expected error, Puppet::Util::CFPropertyList likes to output
    # a couple of messages to STDERR. At runtime I'd like those to display,
    # but in THIS spec test I'm rerouting stderr so it doesn't spam the console
    $stderr.reopen('/dev/null', 'w')
    expect { subject.read_plist('plist.file') }.should \
      raise_error(RuntimeError, /A plist file could not be properly read by Puppet::Util::CFPropertyList/)
  end
end
