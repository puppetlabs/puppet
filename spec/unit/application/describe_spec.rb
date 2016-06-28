#! /usr/bin/env ruby
require 'spec_helper'

require 'puppet/application/describe'

describe Puppet::Application::Describe do
  before :each do
    @describe = Puppet::Application[:describe]
  end

  it "should declare a main command" do
    expect(@describe).to respond_to(:main)
  end

  it "should declare a preinit block" do
    expect(@describe).to respond_to(:preinit)
  end

  [:providers,:list,:meta].each do |option|
    it "should declare handle_#{option} method" do
      expect(@describe).to respond_to("handle_#{option}".to_sym)
    end

    it "should store argument value when calling handle_#{option}" do
      @describe.options.expects(:[]=).with("#{option}".to_sym, 'arg')
      @describe.send("handle_#{option}".to_sym, 'arg')
    end
  end


  describe "in preinit" do
    it "should set options[:parameters] to true" do
      @describe.preinit

      expect(@describe.options[:parameters]).to be_truthy
    end
  end

  describe "when handling parameters" do
    it "should set options[:parameters] to false" do
      @describe.handle_short(nil)

      expect(@describe.options[:parameters]).to be_falsey
    end
  end

  describe "during setup" do
    it "should collect arguments in options[:types]" do
      @describe.command_line.stubs(:args).returns(['1','2'])
      @describe.setup

      expect(@describe.options[:types]).to eq(['1','2'])
    end
  end

  describe "when running" do

    before :each do
      @typedoc = stub 'type_doc'
      TypeDoc.stubs(:new).returns(@typedoc)
    end

    it "should call list_types if options list is set" do
      @describe.options[:list] = true

      @typedoc.expects(:list_types)

      @describe.run_command
    end

    it "should call format_type for each given types" do
      @describe.options[:list] = false
      @describe.options[:types] = ['type']

      @typedoc.expects(:format_type).with('type', @describe.options)
      @describe.run_command
    end
  end

  it "should format text with long non-space runs without garbling" do
    @f = Formatter.new(76)
 
    @teststring = <<TESTSTRING
. 12345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890 nick@magpie.puppetlabs.lan
**this part should not repeat!**
TESTSTRING
    @expected_result = <<EXPECTED
.
1234567890123456789012345678901234567890123456789012345678901234567890123456
7890123456789012345678901234567890 nick@magpie.puppetlabs.lan
**this part should not repeat!**
EXPECTED

    expect(@f.wrap(@teststring, {:indent => 0, :scrub => true})).to eql(@expected_result)
## here

    @teststring = <<TESTSTRING
Manages SSH authorized keys. Currently only type 2 keys are supported.

      In their native habitat, SSH keys usually appear as a single long line. This
      resource type requires you to split that line into several attributes. Thus, a
      key that appears in your `~/.ssh/id_rsa.pub` file like this...

          ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEAy5mtOAMHwA2ZAIfW6Ap70r+I4EclYHEec5xIN59ROUjss23Skb1OtjzYpVPaPH8mSdSmsN0JHaBLiRcu7stl4O8D8zA4mz/vw32yyQ/Kqaxw8l0K76k6t2hKOGqLTY4aFbFISV6GDh7MYLn8KU7cGp96J+caO5R5TqtsStytsUhSyqH+iIDh4e4+BrwTc6V4Y0hgFxaZV5d18mLA4EPYKeG5+zyBCVu+jueYwFqM55E0tHbfiaIN9IzdLV+7NEEfdLkp6w2baLKPqWUBmuvPF1Mn3FwaFLjVsMT3GQeMue6b3FtUdTDeyAYoTxrsRo/WnDkS6Pa3YhrFwjtUqXfdaQ== nick@magpie.puppetlabs.lan

      ...would translate to the following resource:

          ssh_authorized_key { 'nick@magpie.puppetlabs.lan':
            user => 'nick',
            type => 'ssh-rsa',
            key  => 'AAAAB3NzaC1yc2EAAAABIwAAAQEAy5mtOAMHwA2ZAIfW6Ap70r+I4EclYHEec5xIN59ROUjss23Skb1OtjzYpVPaPH8mSdSmsN0JHaBLiRcu7stl4O8D8zA4mz/vw32yyQ/Kqaxw8l0K76k6t2hKOGqLTY4aFbFISV6GDh7MYLn8KU7cGp96J+caO5R5TqtsStytsUhSyqH+iIDh4e4+BrwTc6V4Y0hgFxaZV5d18mLA4EPYKeG5+zyBCVu+jueYwFqM55E0tHbfiaIN9IzdLV+7NEEfdLkp6w2baLKPqWUBmuvPF1Mn3FwaFLjVsMT3GQeMue6b3FtUdTDeyAYoTxrsRo/WnDkS6Pa3YhrFwjtUqXfdaQ==',
          }

      To ensure that only the currently approved keys are present, you can purge
      unmanaged SSH keys on a per-user basis. Do this with the `user` resource
      type's `purge_ssh_keys` attribute:

          user { 'nick':
            ensure         => present,
            purge_ssh_keys => true,
          }

      This will remove any keys in `~/.ssh/authorized_keys` that aren't being
      managed with `ssh_authorized_key` resources. See the documentation of the
      `user` type for more details.
TESTSTRING

    @expected_result = <<RESULT
Manages SSH authorized keys. Currently only type 2 keys are supported.
In their native habitat, SSH keys usually appear as a single long line. This
      resource type requires you to split that line into several attributes.
Thus, a
      key that appears in your `~/.ssh/id_rsa.pub` file like this...
    ssh-rsa
AAAAB3NzaC1yc2EAAAABIwAAAQEAy5mtOAMHwA2ZAIfW6Ap70r+I4EclYHEec5xIN59ROUjss23S
kb1OtjzYpVPaPH8mSdSmsN0JHaBLiRcu7stl4O8D8zA4mz/vw32yyQ/Kqaxw8l0K76k6t2hKOGqL
TY4aFbFISV6GDh7MYLn8KU7cGp96J+caO5R5TqtsStytsUhSyqH+iIDh4e4+BrwTc6V4Y0hgFxaZ
V5d18mLA4EPYKeG5+zyBCVu+jueYwFqM55E0tHbfiaIN9IzdLV+7NEEfdLkp6w2baLKPqWUBmuvP
F1Mn3FwaFLjVsMT3GQeMue6b3FtUdTDeyAYoTxrsRo/WnDkS6Pa3YhrFwjtUqXfdaQ==
nick@magpie.puppetlabs.lan
...would translate to the following resource:
    ssh_authorized_key { 'nick@magpie.puppetlabs.lan':
            user => 'nick',
            type => 'ssh-rsa',
            key  =>
'AAAAB3NzaC1yc2EAAAABIwAAAQEAy5mtOAMHwA2ZAIfW6Ap70r+I4EclYHEec5xIN59ROUjss23
Skb1OtjzYpVPaPH8mSdSmsN0JHaBLiRcu7stl4O8D8zA4mz/vw32yyQ/Kqaxw8l0K76k6t2hKOGq
LTY4aFbFISV6GDh7MYLn8KU7cGp96J+caO5R5TqtsStytsUhSyqH+iIDh4e4+BrwTc6V4Y0hgFxa
ZV5d18mLA4EPYKeG5+zyBCVu+jueYwFqM55E0tHbfiaIN9IzdLV+7NEEfdLkp6w2baLKPqWUBmuv
PF1Mn3FwaFLjVsMT3GQeMue6b3FtUdTDeyAYoTxrsRo/WnDkS6Pa3YhrFwjtUqXfdaQ==',
          }
To ensure that only the currently approved keys are present, you can purge
      unmanaged SSH keys on a per-user basis. Do this with the `user`
resource
      type's `purge_ssh_keys` attribute:
    user { 'nick':
            ensure         => present,
            purge_ssh_keys => true,
          }
This will remove any keys in `~/.ssh/authorized_keys` that aren't being
      managed with `ssh_authorized_key` resources. See the documentation of
the
      `user` type for more details.
RESULT

   expect(@f.wrap(@teststring, {:indent => 0, :scrub => true})).to eql(@expected_result)

  end
end
