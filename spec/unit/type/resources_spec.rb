require 'spec_helper'

# A type and provider that can be purged
Puppet::Type.newtype(:purgeable_test) do
  ensurable
  newparam(:name) {}
end
Puppet::Type.type(:purgeable_test).provide(:purgeable_test) do
  def self.instances
    []
  end
end

resources = Puppet::Type.type(:resources)

# There are still plenty of tests to port over from test/.
describe resources do
  before :each do
    described_class.reset_system_users_max_uid!
  end

  context "when initializing" do
    it "should fail if the specified resource type does not exist" do
      allow(Puppet::Type).to receive(:type) do
        expect(x.to_s.downcase).to eq("resources")
      end.and_return(resources)
      expect(Puppet::Type).to receive(:type).with("nosuchtype").and_return(nil)
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
      allow(instance.resource_type).to receive(:validproperty?).with(:ensure).and_return(false)
      expect { instance[:purge] = 'yes' }.to raise_error Puppet::Error, /Purging is only supported on types that accept 'ensure'/
    end

    it "cannot be set to true for a resource type that does not have instances" do
      allow(instance.resource_type).to receive(:respond_to?).with(:instances).and_return(false)
      expect { instance[:purge] = 'yes' }.to raise_error Puppet::Error, /Purging resources of type file is not supported/
    end

    it "can be set to true for a resource type that has instances and can accept ensure" do
      allow(instance.resource_type).to receive(:validproperty?).and_return(true)
      expect { instance[:purge] = 'yes' }.to_not raise_error
    end
  end

  context "#check_user purge behaviour" do
    context "with unless_system_user => true" do
      before do
        @res = Puppet::Type.type(:resources).new :name => :user, :purge => true, :unless_system_user => true
        @res.catalog = Puppet::Resource::Catalog.new
        allow(Puppet::FileSystem).to receive(:exist?).with('/etc/login.defs').and_return(false)
      end

      it "should never purge hardcoded system users" do
        %w{root nobody bin noaccess daemon sys}.each do |sys_user|
          expect(@res.user_check(Puppet::Type.type(:user).new(:name => sys_user))).to be_falsey
        end
      end

      it "should not purge system users if unless_system_user => true" do
        user_hash = {:name => 'system_user', :uid => 125, :system => true}
        user = Puppet::Type.type(:user).new(user_hash)
        allow(user).to receive(:retrieve_resource).and_return(Puppet::Resource.new("user", user_hash[:name], :parameters => user_hash))
        expect(@res.user_check(user)).to be_falsey
      end

      it "should purge non-system users if unless_system_user => true" do
        user_hash = {:name => 'system_user', :uid => described_class.system_users_max_uid + 1, :system => true}
        user = Puppet::Type.type(:user).new(user_hash)
        allow(user).to receive(:retrieve_resource).and_return(Puppet::Resource.new("user", user_hash[:name], :parameters => user_hash))
        expect(@res.user_check(user)).to be_truthy
      end

      it "should not purge system users under 600 if unless_system_user => 600" do
        res = Puppet::Type.type(:resources).new :name => :user, :purge => true, :unless_system_user => 600
        res.catalog = Puppet::Resource::Catalog.new
        user_hash = {:name => 'system_user', :uid => 500, :system => true}
        user = Puppet::Type.type(:user).new(user_hash)
        allow(user).to receive(:retrieve_resource).and_return(Puppet::Resource.new("user", user_hash[:name], :parameters => user_hash))
        expect(res.user_check(user)).to be_falsey
      end

      it "should not purge Windows system users" do
        res = Puppet::Type.type(:resources).new :name => :user, :purge => true
        res.catalog = Puppet::Resource::Catalog.new
        user_hash = {:name => 'Administrator', :uid => 'S-1-5-21-12345-500'}
        user = Puppet::Type.type(:user).new(user_hash)
        allow(user).to receive(:retrieve_resource).and_return(Puppet::Resource.new("user", user_hash[:name], :parameters => user_hash))
        expect(res.user_check(user)).to be_falsey
      end

      it "should not purge Windows system users" do
        res = Puppet::Type.type(:resources).new :name => :user, :purge => true
        res.catalog = Puppet::Resource::Catalog.new
        user_hash = {:name => 'other', :uid => 'S-1-5-21-12345-1001'}
        user = Puppet::Type.type(:user).new(user_hash)
        allow(user).to receive(:retrieve_resource).and_return(Puppet::Resource.new("user", user_hash[:name], :parameters => user_hash))
        expect(res.user_check(user)).to be_truthy
      end
    end

    %w(FreeBSD OpenBSD).each do |os|
      context "on #{os}" do
        before :each do
          allow(Facter).to receive(:value).with(:kernel).and_return(os)
          allow(Facter).to receive(:value).with(:operatingsystem).and_return(os)
          allow(Facter).to receive(:value).with(:osfamily).and_return(os)
          allow(Puppet::FileSystem).to receive(:exist?).with('/etc/login.defs').and_return(false)
          @res = Puppet::Type.type(:resources).new :name => :user, :purge => true, :unless_system_user => true
          @res.catalog = Puppet::Resource::Catalog.new
        end

        it "should not purge system users under 1000" do
          user_hash = {:name => 'system_user', :uid => 999}
          user = Puppet::Type.type(:user).new(user_hash)
          allow(user).to receive(:retrieve_resource).and_return(Puppet::Resource.new("user", user_hash[:name], :parameters => user_hash))
          expect(@res.user_check(user)).to be_falsey
        end

        it "should purge users over 999" do
          user_hash = {:name => 'system_user', :uid => 1000}
          user = Puppet::Type.type(:user).new(user_hash)
          allow(user).to receive(:retrieve_resource).and_return(Puppet::Resource.new("user", user_hash[:name], :parameters => user_hash))
          expect(@res.user_check(user)).to be_truthy
        end
      end
    end

    context 'with login.defs present' do
      before :each do
        expect(Puppet::FileSystem).to receive(:exist?).with('/etc/login.defs').and_return(true)
        expect(Puppet::FileSystem).to receive(:each_line).with('/etc/login.defs').and_yield(' UID_MIN         1234 # UID_MIN comment ')
        @res = Puppet::Type.type(:resources).new :name => :user, :purge => true, :unless_system_user => true
        @res.catalog = Puppet::Resource::Catalog.new
      end

      it 'should not purge a system user' do
        user_hash = {:name => 'system_user', :uid => 1233}
        user = Puppet::Type.type(:user).new(user_hash)
        allow(user).to receive(:retrieve_resource).and_return(Puppet::Resource.new("user", user_hash[:name], :parameters => user_hash))
        expect(@res.user_check(user)).to be_falsey
      end

      it 'should purge a non-system user' do
        user_hash = {:name => 'system_user', :uid => 1234}
        user = Puppet::Type.type(:user).new(user_hash)
        allow(user).to receive(:retrieve_resource).and_return(Puppet::Resource.new("user", user_hash[:name], :parameters => user_hash))
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
          allow(user).to receive(:retrieve_resource).and_return(Puppet::Resource.new("user", user_hash[:name], :parameters => user_hash))
          expect(@res.user_check(user)).to be_truthy
        end

        it "should not purge uids that are in a specified array" do
          user_hash = {:name => 'special_user', :uid => 15000}
          user = Puppet::Type.type(:user).new(user_hash)
          allow(user).to receive(:retrieve_resource).and_return(Puppet::Resource.new("user", user_hash[:name], :parameters => user_hash))
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
          allow(user).to receive(:retrieve_resource).and_return(Puppet::Resource.new("user", user_hash[:name], :parameters => user_hash))
          expect(@res.user_check(user)).to be_truthy
        end

        it "should not purge uids that are specified" do
          user_hash = {:name => 'special_user', :uid => 15_000}
          user = Puppet::Type.type(:user).new(user_hash)
          allow(user).to receive(:retrieve_resource).and_return(Puppet::Resource.new("user", user_hash[:name], :parameters => user_hash))
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
          allow(user).to receive(:retrieve_resource).and_return(Puppet::Resource.new("user", user_hash[:name], :parameters => user_hash))
          expect(@res.user_check(user)).to be_truthy
        end

        it "should not purge uids that are specified" do
          user_hash = {:name => 'special_user', :uid => 15_000}
          user = Puppet::Type.type(:user).new(user_hash)
          allow(user).to receive(:retrieve_resource).and_return(Puppet::Resource.new("user", user_hash[:name], :parameters => user_hash))
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
          allow(user).to receive(:retrieve_resource).and_return(Puppet::Resource.new("user", user_hash[:name], :parameters => user_hash))
          expect(@res.user_check(user)).to be_falsey
        end

        it "should not purge specified ids" do
          user_hash = {:name => 'special_user', :uid => 16_666}
          user = Puppet::Type.type(:user).new(user_hash)
          allow(user).to receive(:retrieve_resource).and_return(Puppet::Resource.new("user", user_hash[:name], :parameters => user_hash))
          expect(@res.user_check(user)).to be_falsey
        end

        it "should purge unspecified ids" do
          user_hash = {:name => 'special_user', :uid => 17_000}
          user = Puppet::Type.type(:user).new(user_hash)
          allow(user).to receive(:retrieve_resource).and_return(Puppet::Resource.new("user", user_hash[:name], :parameters => user_hash))
          expect(@res.user_check(user)).to be_truthy
        end
      end
    end
  end

  context "#generate" do
    before do
      @purgee = Puppet::Type.type(:purgeable_test).new(:name => 'localhost')
      @catalog = Puppet::Resource::Catalog.new
    end

    context "when dealing with non-purging resources" do
      before do
        @resources = Puppet::Type.type(:resources).new(:name => 'purgeable_test')
      end

      it "should not generate any resource" do
        expect(@resources.generate).to be_empty
      end
    end

    context "when the catalog contains a purging resource" do
      before do
        @resources = Puppet::Type.type(:resources).new(:name => 'purgeable_test', :purge => true)
        @purgeable_resource = Puppet::Type.type(:purgeable_test).new(:name => 'localhost')
        @catalog.add_resource @resources
      end

      it "should not generate a duplicate of that resource" do
        allow(Puppet::Type.type(:purgeable_test)).to receive(:instances).and_return([@purgee])
        @catalog.add_resource @purgee
        expect(@resources.generate.collect { |r| r.ref }).not_to include(@purgee.ref)
      end

      it "should not include the skipped system users" do
        res = Puppet::Type.type(:resources).new :name => :user, :purge => true
        res.catalog = Puppet::Resource::Catalog.new

        root = Puppet::Type.type(:user).new(:name => "root")
        expect(Puppet::Type.type(:user)).to receive(:instances).and_return([root])

        list = res.generate

        names = list.collect { |r| r[:name] }
        expect(names).not_to be_include("root")
      end

      context "when generating a purgeable resource" do
        it "should be included in the generated resources" do
          allow(Puppet::Type.type(:purgeable_test)).to receive(:instances).and_return([@purgeable_resource])
          expect(@resources.generate.collect { |r| r.ref }).to include(@purgeable_resource.ref)
        end

        context "when the instance's do not have an ensure property" do
          it "should not be included in the generated resources" do
            @no_ensure_resource = Puppet::Type.type(:exec).new(:name => "#{File.expand_path('/usr/bin/env')} echo")
            allow(Puppet::Type.type(:purgeable_test)).to receive(:instances).and_return([@no_ensure_resource])
            expect(@resources.generate.collect { |r| r.ref }).not_to include(@no_ensure_resource.ref)
          end
        end

        context "when the instance's ensure property does not accept absent" do
          it "should not be included in the generated resources" do
            # We have a :confine block that calls execute in our upstart provider, which fails
            # on jruby. Thus, we stub it out here since we don't care to do any assertions on it.
            # This is only an issue if you're running these unit tests on a platform where upstart
            # is a default provider, like Ubuntu trusty.
            allow(Puppet::Util::Execution).to receive(:execute)

            @no_absent_resource = Puppet::Type.type(:service).new(:name => 'foobar')
            allow(Puppet::Type.type(:purgeable_test)).to receive(:instances).and_return([@no_absent_resource])
            expect(@resources.generate.collect { |r| r.ref }).not_to include(@no_absent_resource.ref)
          end
        end

        context "when checking the instance fails" do
          it "should not be included in the generated resources" do
            @purgeable_resource = Puppet::Type.type(:purgeable_test).new(:name => 'foobar')
            allow(Puppet::Type.type(:purgeable_test)).to receive(:instances).and_return([@purgeable_resource])
            expect(@resources).to receive(:check).with(@purgeable_resource).and_return(false)
            expect(@resources.generate.collect { |r| r.ref }).not_to include(@purgeable_resource.ref)
          end
        end
      end
    end
  end
end
