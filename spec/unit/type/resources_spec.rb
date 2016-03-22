#! /usr/bin/env ruby
require 'spec_helper'

resources = Puppet::Type.type(:resources)

# There are still plenty of tests to port over from test/.
describe resources do

  before :each do
    described_class.reset_system_users_max_uid!
  end

  context "when initializing" do
    it "should fail if the specified resource type does not exist" do
      Puppet::Type.stubs(:type).with { |x| x.to_s.downcase == "resources"}.returns resources
      Puppet::Type.expects(:type).with("nosuchtype").returns nil
      expect { resources.new :name => "nosuchtype" }.to raise_error(Puppet::Error)
    end

    it "should not fail when the specified resource type exists" do
      expect { resources.new :name => "file" }.not_to raise_error
    end

    it "should set its :resource_type attribute" do
      expect(resources.new(:name => "file").resource_type).to eq(Puppet::Type.type(:file))
    end
  end

  context "purge" do
    let (:instance) { described_class.new(:name => 'file') }

    it "defaults to false" do
      expect(instance[:purge]).to be_falsey
    end

    it "can be set to false" do
      instance[:purge] = 'false'
    end

    it "cannot be set to true for a resource type that does not accept ensure" do
      instance.resource_type.stubs(:respond_to?).returns true
      instance.resource_type.stubs(:validproperty?).returns false
      expect { instance[:purge] = 'yes' }.to raise_error Puppet::Error
    end

    it "cannot be set to true for a resource type that does not have instances" do
      instance.resource_type.stubs(:respond_to?).returns false
      instance.resource_type.stubs(:validproperty?).returns true
      expect { instance[:purge] = 'yes' }.to raise_error Puppet::Error
    end

    it "can be set to true for a resource type that has instances and can accept ensure" do
      instance.resource_type.stubs(:respond_to?).returns true
      instance.resource_type.stubs(:validproperty?).returns true
      expect { instance[:purge] = 'yes' }.to_not raise_error
    end
  end

  context "#check_user purge behaviour" do
    context "with unless_system_user => true" do
      before do
        @res = Puppet::Type.type(:resources).new :name => :user, :purge => true, :unless_system_user => true
        @res.catalog = Puppet::Resource::Catalog.new
        Puppet::FileSystem.stubs(:exist?).with('/etc/login.defs').returns false
      end

      it "should never purge hardcoded system users" do
        %w{root nobody bin noaccess daemon sys}.each do |sys_user|
          expect(@res.user_check(Puppet::Type.type(:user).new(:name => sys_user))).to be_falsey
        end
      end

      it "should not purge system users if unless_system_user => true" do
        user_hash = {:name => 'system_user', :uid => 125, :system => true}
        user = Puppet::Type.type(:user).new(user_hash)
        user.stubs(:retrieve_resource).returns Puppet::Resource.new("user", user_hash[:name], :parameters => user_hash)
        expect(@res.user_check(user)).to be_falsey
      end

      it "should purge non-system users if unless_system_user => true" do
        user_hash = {:name => 'system_user', :uid => described_class.system_users_max_uid + 1, :system => true}
        user = Puppet::Type.type(:user).new(user_hash)
        user.stubs(:retrieve_resource).returns Puppet::Resource.new("user", user_hash[:name], :parameters => user_hash)
        expect(@res.user_check(user)).to be_truthy
      end

      it "should not purge system users under 600 if unless_system_user => 600" do
        res = Puppet::Type.type(:resources).new :name => :user, :purge => true, :unless_system_user => 600
        res.catalog = Puppet::Resource::Catalog.new
        user_hash = {:name => 'system_user', :uid => 500, :system => true}
        user = Puppet::Type.type(:user).new(user_hash)
        user.stubs(:retrieve_resource).returns Puppet::Resource.new("user", user_hash[:name], :parameters => user_hash)
        expect(res.user_check(user)).to be_falsey
      end
    end

    %w(FreeBSD OpenBSD).each do |os|
      context "on #{os}" do
        before :each do
          Facter.stubs(:value).with(:kernel).returns(os)
          Facter.stubs(:value).with(:operatingsystem).returns(os)
          Facter.stubs(:value).with(:osfamily).returns(os)
          Puppet::FileSystem.stubs(:exist?).with('/etc/login.defs').returns false
          @res = Puppet::Type.type(:resources).new :name => :user, :purge => true, :unless_system_user => true
          @res.catalog = Puppet::Resource::Catalog.new
        end

        it "should not purge system users under 1000" do
          user_hash = {:name => 'system_user', :uid => 999}
          user = Puppet::Type.type(:user).new(user_hash)
          user.stubs(:retrieve_resource).returns Puppet::Resource.new("user", user_hash[:name], :parameters => user_hash)
          expect(@res.user_check(user)).to be_falsey
        end

        it "should purge users over 999" do
          user_hash = {:name => 'system_user', :uid => 1000}
          user = Puppet::Type.type(:user).new(user_hash)
          user.stubs(:retrieve_resource).returns Puppet::Resource.new("user", user_hash[:name], :parameters => user_hash)
          expect(@res.user_check(user)).to be_truthy
        end
      end
    end

    context 'with login.defs present' do
      before :each do
        Puppet::FileSystem.expects(:exist?).with('/etc/login.defs').returns true
        Puppet::FileSystem.expects(:each_line).with('/etc/login.defs').yields(' UID_MIN         1234 # UID_MIN comment ')
        @res = Puppet::Type.type(:resources).new :name => :user, :purge => true, :unless_system_user => true
        @res.catalog = Puppet::Resource::Catalog.new
      end

      it 'should not purge a system user' do
        user_hash = {:name => 'system_user', :uid => 1233}
        user = Puppet::Type.type(:user).new(user_hash)
        user.stubs(:retrieve_resource).returns Puppet::Resource.new("user", user_hash[:name], :parameters => user_hash)
        expect(@res.user_check(user)).to be_falsey
      end

      it 'should purge a non-system user' do
        user_hash = {:name => 'system_user', :uid => 1234}
        user = Puppet::Type.type(:user).new(user_hash)
        user.stubs(:retrieve_resource).returns Puppet::Resource.new("user", user_hash[:name], :parameters => user_hash)
        expect(@res.user_check(user)).to be_truthy
      end
    end

    context "with unless_uid" do
      context "with a uid array" do
        before do
          @res = Puppet::Type.type(:resources).new :name => :user, :purge => true, :unless_uid => [15_000, 15_001, 15_002]
          @res.catalog = Puppet::Resource::Catalog.new
        end

        it "should purge uids that are not in a specified array" do
          user_hash = {:name => 'special_user', :uid => 25_000}
          user = Puppet::Type.type(:user).new(user_hash)
          user.stubs(:retrieve_resource).returns Puppet::Resource.new("user", user_hash[:name], :parameters => user_hash)
          expect(@res.user_check(user)).to be_truthy
        end

        it "should not purge uids that are in a specified array" do
          user_hash = {:name => 'special_user', :uid => 15000}
          user = Puppet::Type.type(:user).new(user_hash)
          user.stubs(:retrieve_resource).returns Puppet::Resource.new("user", user_hash[:name], :parameters => user_hash)
          expect(@res.user_check(user)).to be_falsey
        end

      end

      context "with a single integer uid" do
        before do
          @res = Puppet::Type.type(:resources).new :name => :user, :purge => true, :unless_uid => 15_000
          @res.catalog = Puppet::Resource::Catalog.new
        end

        it "should purge uids that are not specified" do
          user_hash = {:name => 'special_user', :uid => 25_000}
          user = Puppet::Type.type(:user).new(user_hash)
          user.stubs(:retrieve_resource).returns Puppet::Resource.new("user", user_hash[:name], :parameters => user_hash)
          expect(@res.user_check(user)).to be_truthy
        end

        it "should not purge uids that are specified" do
          user_hash = {:name => 'special_user', :uid => 15_000}
          user = Puppet::Type.type(:user).new(user_hash)
          user.stubs(:retrieve_resource).returns Puppet::Resource.new("user", user_hash[:name], :parameters => user_hash)
          expect(@res.user_check(user)).to be_falsey
        end
      end

      context "with a single string uid" do
        before do
          @res = Puppet::Type.type(:resources).new :name => :user, :purge => true, :unless_uid => '15000'
          @res.catalog = Puppet::Resource::Catalog.new
        end

        it "should purge uids that are not specified" do
          user_hash = {:name => 'special_user', :uid => 25_000}
          user = Puppet::Type.type(:user).new(user_hash)
          user.stubs(:retrieve_resource).returns Puppet::Resource.new("user", user_hash[:name], :parameters => user_hash)
          expect(@res.user_check(user)).to be_truthy
        end

        it "should not purge uids that are specified" do
          user_hash = {:name => 'special_user', :uid => 15_000}
          user = Puppet::Type.type(:user).new(user_hash)
          user.stubs(:retrieve_resource).returns Puppet::Resource.new("user", user_hash[:name], :parameters => user_hash)
          expect(@res.user_check(user)).to be_falsey
        end
      end

      context "with a mixed uid array" do
        before do
          @res = Puppet::Type.type(:resources).new :name => :user, :purge => true, :unless_uid => ['15000', 16_666]
          @res.catalog = Puppet::Resource::Catalog.new
        end

        it "should not purge ids in the range" do
          user_hash = {:name => 'special_user', :uid => 15_000}
          user = Puppet::Type.type(:user).new(user_hash)
          user.stubs(:retrieve_resource).returns Puppet::Resource.new("user", user_hash[:name], :parameters => user_hash)
          expect(@res.user_check(user)).to be_falsey
        end

        it "should not purge specified ids" do
          user_hash = {:name => 'special_user', :uid => 16_666}
          user = Puppet::Type.type(:user).new(user_hash)
          user.stubs(:retrieve_resource).returns Puppet::Resource.new("user", user_hash[:name], :parameters => user_hash)
          expect(@res.user_check(user)).to be_falsey
        end

        it "should purge unspecified ids" do
          user_hash = {:name => 'special_user', :uid => 17_000}
          user = Puppet::Type.type(:user).new(user_hash)
          user.stubs(:retrieve_resource).returns Puppet::Resource.new("user", user_hash[:name], :parameters => user_hash)
          expect(@res.user_check(user)).to be_truthy
        end
      end

    end
  end

  context "#generate" do
    before do
      @host1 = Puppet::Type.type(:host).new(:name => 'localhost', :ip => '127.0.0.1')
      @catalog = Puppet::Resource::Catalog.new
    end

      context "when dealing with non-purging resources" do
        before do
          @resources = Puppet::Type.type(:resources).new(:name => 'host')
        end

        it "should not generate any resource" do
          expect(@resources.generate).to be_empty
        end
      end

      context "when the catalog contains a purging resource" do
        before do
          @resources = Puppet::Type.type(:resources).new(:name => 'host', :purge => true)
          @purgeable_resource = Puppet::Type.type(:host).new(:name => 'localhost', :ip => '127.0.0.1')
          @catalog.add_resource @resources
        end

        it "should not generate a duplicate of that resource" do
          Puppet::Type.type(:host).stubs(:instances).returns [@host1]
          @catalog.add_resource @host1
          expect(@resources.generate.collect { |r| r.ref }).not_to include(@host1.ref)
        end

        it "should not include the skipped system users" do
          res = Puppet::Type.type(:resources).new :name => :user, :purge => true
          res.catalog = Puppet::Resource::Catalog.new

          root = Puppet::Type.type(:user).new(:name => "root")
          Puppet::Type.type(:user).expects(:instances).returns [ root ]

          list = res.generate

          names = list.collect { |r| r[:name] }
          expect(names).not_to be_include("root")
        end

        context "when generating a purgeable resource" do
          it "should be included in the generated resources" do
            Puppet::Type.type(:host).stubs(:instances).returns [@purgeable_resource]
            expect(@resources.generate.collect { |r| r.ref }).to include(@purgeable_resource.ref)
          end
        end

        context "when the instance's do not have an ensure property" do
          it "should not be included in the generated resources" do
            @no_ensure_resource = Puppet::Type.type(:exec).new(:name => "#{File.expand_path('/usr/bin/env')} echo")
            Puppet::Type.type(:host).stubs(:instances).returns [@no_ensure_resource]
            expect(@resources.generate.collect { |r| r.ref }).not_to include(@no_ensure_resource.ref)
          end
        end

        context "when the instance's ensure property does not accept absent" do
          it "should not be included in the generated resources" do
            @no_absent_resource = Puppet::Type.type(:service).new(:name => 'foobar')
            Puppet::Type.type(:host).stubs(:instances).returns [@no_absent_resource]
            expect(@resources.generate.collect { |r| r.ref }).not_to include(@no_absent_resource.ref)
          end
        end

        context "when checking the instance fails" do
          it "should not be included in the generated resources" do
            @purgeable_resource = Puppet::Type.type(:host).new(:name => 'foobar')
            Puppet::Type.type(:host).stubs(:instances).returns [@purgeable_resource]
            @resources.expects(:check).with(@purgeable_resource).returns(false)
            expect(@resources.generate.collect { |r| r.ref }).not_to include(@purgeable_resource.ref)
          end
        end
      end
  end
end
