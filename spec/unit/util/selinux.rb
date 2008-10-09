#!/usr/bin/env ruby

Dir.chdir(File.dirname(__FILE__)) { (s = lambda { |f| File.exist?(f) ? require(f) : Dir.chdir("..") { s.call(f) } }).call("spec/spec_helper.rb") }

require 'puppet/util/selinux'
include Puppet::Util::SELinux

describe Puppet::Util::SELinux do

    describe "selinux_support?" do
        it "should return :true if this system has SELinux enabled" do
             FileTest.expects(:exists?).with("/selinux/enforce").returns true
             selinux_support?.should be_true
        end

        it "should return :false if this system lacks SELinux" do
             FileTest.expects(:exists?).with("/selinux/enforce").returns false
             selinux_support?.should be_false
        end
    end

    describe "get_selinux_current_context" do
        it "should return nil if no SELinux support" do
            self.expects(:selinux_support?).returns false
            get_selinux_current_context("/foo").should be_nil
        end

        it "should return a context" do
            self.expects(:selinux_support?).returns true
            self.expects(:execpipe).with("stat -c %C /foo").yields ["user_u:role_r:type_t:s0\n"]
            get_selinux_current_context("/foo").should == "user_u:role_r:type_t:s0"
        end

        it "should return nil if an exception is raised calling stat" do
            self.expects(:selinux_support?).returns true
            self.expects(:execpipe).with("stat -c %C /foo").raises(Puppet::ExecutionFailure, 'error')
            get_selinux_current_context("/foo").should be_nil
        end

        it "should return nil if stat finds an unlabeled file" do
            self.expects(:selinux_support?).returns true
            self.expects(:execpipe).with("stat -c %C /foo").yields ["(null)\n"]
            get_selinux_current_context("/foo").should be_nil
        end
    end

    describe "get_selinux_default_context" do
        it "should return nil if no SELinux support" do
            self.expects(:selinux_support?).returns false
            get_selinux_default_context("/foo").should be_nil
        end

        it "should return nil if matchpathcon is not executable" do
            self.expects(:selinux_support?).returns true
            FileTest.expects(:executable?).with("/usr/sbin/matchpathcon").returns false
            get_selinux_default_context("/foo").should be_nil
        end

        it "should return a context if a default context exists" do
            self.expects(:selinux_support?).returns true
            FileTest.expects(:executable?).with("/usr/sbin/matchpathcon").returns true
            self.expects(:execpipe).with("/usr/sbin/matchpathcon /foo").yields ["/foo\tuser_u:role_r:type_t:s0\n"]
            get_selinux_default_context("/foo").should == "user_u:role_r:type_t:s0"
        end

        it "should return nil if an exception is raised calling matchpathcon" do
            self.expects(:selinux_support?).returns true
            FileTest.expects(:executable?).with("/usr/sbin/matchpathcon").returns true
            self.expects(:execpipe).with("/usr/sbin/matchpathcon /foo").raises(Puppet::ExecutionFailure, 'error')
            get_selinux_default_context("/foo").should be_nil
        end
    end

    describe "parse_selinux_context" do
        it "should return nil if no context is passed" do
            parse_selinux_context(:seluser, nil).should be_nil
        end

        it "should return nil if the context is 'unlabeled'" do
            parse_selinux_context(:seluser, "unlabeled").should be_nil
        end

        it "should return the user type when called with :seluser" do
            parse_selinux_context(:seluser, "user_u:role_r:type_t:s0").should == "user_u"
        end

        it "should return the role type when called with :selrole" do
            parse_selinux_context(:selrole, "user_u:role_r:type_t:s0").should == "role_r"
        end

        it "should return the type type when called with :seltype" do
            parse_selinux_context(:seltype, "user_u:role_r:type_t:s0").should == "type_t"
        end

        it "should return nil for :selrange when no range is returned" do
            parse_selinux_context(:selrange, "user_u:role_r:type_t").should be_nil
        end

        it "should return the range type when called with :selrange" do
            parse_selinux_context(:selrange, "user_u:role_r:type_t:s0").should == "s0"
        end

        describe "with a variety of SELinux range formats" do
            ['s0', 's0:c3', 's0:c3.c123', 's0:c3,c5,c8', 'TopSecret', 'TopSecret,Classified', 'Patient_Record'].each do |range|
                it "should parse range '#{range}'" do
                    parse_selinux_context(:selrange, "user_u:role_r:type_t:#{range}").should == range
                end
            end
        end
    end

    describe "set_selinux_context" do
        it "should return nil if there is no SELinux support" do
            self.expects(:selinux_support?).returns false
            set_selinux_context("/foo", "user_u:role_r:type_t:s0").should be_nil
        end

        it "should use chcon to set a context" do
            self.expects(:selinux_support?).returns true
            self.expects(:system).with("chcon  user_u:role_r:type_t:s0 /foo").returns 0
            set_selinux_context("/foo", "user_u:role_r:type_t:s0").should be_true
        end

        it "should use chcon to set user_u user context" do
            self.expects(:selinux_support?).returns true
            self.expects(:system).with("chcon -u user_u /foo").returns 0
            set_selinux_context("/foo", "user_u", :seluser).should be_true
        end

        it "should use chcon to set role_r role context" do
            self.expects(:selinux_support?).returns true
            self.expects(:system).with("chcon -r role_r /foo").returns 0
            set_selinux_context("/foo", "role_r", :selrole).should be_true
        end

        it "should use chcon to set type_t type context" do
            self.expects(:selinux_support?).returns true
            self.expects(:system).with("chcon -t type_t /foo").returns 0
            set_selinux_context("/foo", "type_t", :seltype).should be_true
        end

        it "should use chcon to set s0:c3,c5 range context" do
            self.expects(:selinux_support?).returns true
            self.expects(:system).with("chcon -l s0:c3,c5 /foo").returns 0
            set_selinux_context("/foo", "s0:c3,c5", :selrange).should be_true
        end
    end

    describe "set_selinux_default_context" do
        it "should return nil if there is no SELinux support" do
            self.expects(:selinux_support?).returns false
            set_selinux_default_context("/foo").should be_nil
        end

        it "should return nil if no default context exists" do
            self.expects(:get_selinux_default_context).with("/foo").returns nil
            set_selinux_default_context("/foo").should be_nil
        end

        it "should do nothing and return nil if the current context matches the default context" do
            self.expects(:get_selinux_default_context).with("/foo").returns "user_u:role_r:type_t"
            self.expects(:get_selinux_current_context).with("/foo").returns "user_u:role_r:type_t"
            set_selinux_default_context("/foo").should be_nil
        end

        it "should set and return the default context if current and default do not match" do
            self.expects(:get_selinux_default_context).with("/foo").returns "user_u:role_r:type_t"
            self.expects(:get_selinux_current_context).with("/foo").returns "olduser_u:role_r:type_t"
            self.expects(:set_selinux_context).with("/foo", "user_u:role_r:type_t").returns true
            set_selinux_default_context("/foo").should == "user_u:role_r:type_t"
        end
    end

end
