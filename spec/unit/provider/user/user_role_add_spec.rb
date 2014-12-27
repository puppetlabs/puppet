require 'spec_helper'
require 'puppet_spec/files'
require 'tempfile'

describe Puppet::Type.type(:user).provider(:user_role_add), :unless => Puppet.features.microsoft_windows? do
  include PuppetSpec::Files
  let(:resource) { Puppet::Type.type(:user).new(:name => 'myuser', :managehome => false, :allowdupe => false) }
  let(:provider) { described_class.new(resource) }

  before do
    resource.stubs(:should).returns "fakeval"
    resource.stubs(:should).with(:keys).returns Hash.new
    resource.stubs(:[]).returns "fakeval"
  end


  describe "#command" do
    before do
      klass = stub("provider")
      klass.stubs(:command).with(:foo).returns("userfoo")
      klass.stubs(:command).with(:role_foo).returns("rolefoo")
      provider.stubs(:class).returns(klass)
    end

    it "should use the command if not a role and ensure!=role" do
      provider.stubs(:is_role?).returns(false)
      provider.stubs(:exists?).returns(false)
      resource.stubs(:[]).with(:ensure).returns(:present)
      provider.class.stubs(:foo)
      expect(provider.command(:foo)).to eq("userfoo")
    end

    it "should use the role command when a role" do
      provider.stubs(:is_role?).returns(true)
      expect(provider.command(:foo)).to eq("rolefoo")
    end

    it "should use the role command when !exists and ensure=role" do
      provider.stubs(:is_role?).returns(false)
      provider.stubs(:exists?).returns(false)
      resource.stubs(:[]).with(:ensure).returns(:role)
      expect(provider.command(:foo)).to eq("rolefoo")
    end
  end

  describe "#transition" do
    it "should return the type set to whatever is passed in" do
      provider.expects(:command).with(:modify).returns("foomod")
      provider.transition("bar").include?("type=bar")
    end
  end

  describe "#create" do
    before do
      provider.stubs(:password=)
    end

    it "should use the add command when the user is not a role" do
      provider.stubs(:is_role?).returns(false)
      provider.expects(:addcmd).returns("useradd")
      provider.expects(:run).at_least_once
      provider.create
    end

    it "should use transition(normal) when the user is a role" do
      provider.stubs(:is_role?).returns(true)
      provider.expects(:transition).with("normal")
      provider.expects(:run)
      provider.create
    end

    it "should set password age rules" do
      resource = Puppet::Type.type(:user).new :name => "myuser", :password_min_age => 5, :password_max_age => 10, :provider => :user_role_add
      provider = described_class.new(resource)
      provider.stubs(:user_attributes)
      provider.stubs(:execute)
      provider.expects(:execute).with { |cmd, *args| args == ["-n", 5, "-x", 10, "myuser"] }
      provider.create
    end
  end

  describe "#destroy" do
    it "should use the delete command if the user exists and is not a role" do
      provider.stubs(:exists?).returns(true)
      provider.stubs(:is_role?).returns(false)
      provider.expects(:deletecmd)
      provider.expects(:run)
      provider.destroy
    end

    it "should use the delete command if the user is a role" do
      provider.stubs(:exists?).returns(true)
      provider.stubs(:is_role?).returns(true)
      provider.expects(:deletecmd)
      provider.expects(:run)
      provider.destroy
    end
  end

  describe "#create_role" do
    it "should use the transition(role) if the user exists" do
      provider.stubs(:exists?).returns(true)
      provider.stubs(:is_role?).returns(false)
      provider.expects(:transition).with("role")
      provider.expects(:run)
      provider.create_role
    end

    it "should use the add command when role doesn't exists" do
      provider.stubs(:exists?).returns(false)
      provider.expects(:addcmd)
      provider.expects(:run)
      provider.create_role
    end
  end

  describe "with :allow_duplicates" do
    before do
      resource.stubs(:allowdupe?).returns true
      provider.stubs(:is_role?).returns(false)
      provider.stubs(:execute)
      resource.stubs(:system?).returns false
      provider.expects(:execute).with { |args| args.include?("-o") }
    end

    it "should add -o when the user is being created" do
      provider.stubs(:password=)
      provider.create
    end

    it "should add -o when the uid is being modified" do
      provider.uid = 150
    end
  end

  [:roles, :auths, :profiles].each do |val|
    context "#send" do
      describe "when getting #{val}" do
        it "should get the user_attributes" do
          provider.expects(:user_attributes)
          provider.send(val)
        end

        it "should get the #{val} attribute" do
          attributes = mock("attributes")
          attributes.expects(:[]).with(val)
          provider.stubs(:user_attributes).returns(attributes)
          provider.send(val)
        end
      end
    end
  end

  describe "#keys" do
    it "should get the user_attributes" do
      provider.expects(:user_attributes)
      provider.keys
    end

    it "should call removed_managed_attributes" do
      provider.stubs(:user_attributes).returns({ :type => "normal", :foo => "something" })
      provider.expects(:remove_managed_attributes)
      provider.keys
    end

    it "should removed managed attribute (type, auths, roles, etc)" do
      provider.stubs(:user_attributes).returns({ :type => "normal", :foo => "something" })
      expect(provider.keys).to eq({ :foo => "something" })
    end
  end

  describe "#add_properties" do
    it "should call build_keys_cmd" do
      resource.stubs(:should).returns ""
      resource.expects(:should).with(:keys).returns({ :foo => "bar" })
      provider.expects(:build_keys_cmd).returns([])
      provider.add_properties
    end

    it "should add the elements of the keys hash to an array" do
      resource.stubs(:should).returns ""
      resource.expects(:should).with(:keys).returns({ :foo => "bar"})
      expect(provider.add_properties).to eq(["-K", "foo=bar"])
    end
  end

  describe "#build_keys_cmd" do
    it "should build cmd array with keypairs separated by -K ending with user" do
      expect(provider.build_keys_cmd({"foo" => "bar", "baz" => "boo"})).to eq(["-K", "foo=bar", "-K", "baz=boo"])
    end
  end

  describe "#keys=" do
    before do
      provider.stubs(:is_role?).returns(false)
    end

    it "should run a command" do
      provider.expects(:run)
      provider.keys=({})
    end

    it "should build the command" do
      resource.stubs(:[]).with(:name).returns("someuser")
      provider.stubs(:command).returns("usermod")
      provider.expects(:build_keys_cmd).returns(["-K", "foo=bar"])
      provider.expects(:run).with(["usermod", "-K", "foo=bar", "someuser"], "modify attribute key pairs")
      provider.keys=({})
    end
  end

  describe "#password" do
    before do
      @array = mock "array"
    end

    it "should readlines of /etc/shadow" do
      File.expects(:readlines).with("/etc/shadow").returns([])
      provider.password
    end

    it "should reject anything that doesn't start with alpha numerics" do
      @array.expects(:reject).returns([])
      File.stubs(:readlines).with("/etc/shadow").returns(@array)
      provider.password
    end

    it "should collect splitting on ':'" do
      @array.stubs(:reject).returns(@array)
      @array.expects(:collect).returns([])
      File.stubs(:readlines).with("/etc/shadow").returns(@array)
      provider.password
    end

    it "should find the matching user" do
      resource.stubs(:[]).with(:name).returns("username")
      @array.stubs(:reject).returns(@array)
      @array.stubs(:collect).returns([["username", "hashedpassword"], ["someoneelse", "theirpassword"]])
      File.stubs(:readlines).with("/etc/shadow").returns(@array)
      expect(provider.password).to eq("hashedpassword")
    end

    it "should get the right password" do
      resource.stubs(:[]).with(:name).returns("username")
      File.stubs(:readlines).with("/etc/shadow").returns(["#comment", "   nonsense", "  ", "username:hashedpassword:stuff:foo:bar:::", "other:pword:yay:::"])
      expect(provider.password).to eq("hashedpassword")
    end
  end

  describe "#password=" do
    let(:path) { tmpfile('etc-shadow') }

    before :each do
      provider.stubs(:target_file_path).returns(path)
    end

    def write_fixture(content)
      File.open(path, 'w') { |f| f.print(content) }
    end

    it "should update the target user" do
      write_fixture <<FIXTURE
fakeval:seriously:15315:0:99999:7:::
FIXTURE
      provider.password = "totally"
      expect(File.read(path)).to match(/^fakeval:totally:/)
    end

    it "should only update the target user" do
      Date.expects(:today).returns Date.new(2011,12,07)
      write_fixture <<FIXTURE
before:seriously:15315:0:99999:7:::
fakeval:seriously:15315:0:99999:7:::
fakevalish:seriously:15315:0:99999:7:::
after:seriously:15315:0:99999:7:::
FIXTURE
      provider.password = "totally"
      expect(File.read(path)).to eq <<EOT
before:seriously:15315:0:99999:7:::
fakeval:totally:15315:0:99999:7:::
fakevalish:seriously:15315:0:99999:7:::
after:seriously:15315:0:99999:7:::
EOT
    end

    # This preserves the current semantics, but is it right? --daniel 2012-02-05
    it "should do nothing if the target user is missing" do
      fixture = <<FIXTURE
before:seriously:15315:0:99999:7:::
fakevalish:seriously:15315:0:99999:7:::
after:seriously:15315:0:99999:7:::
FIXTURE

      write_fixture fixture
      provider.password = "totally"
      expect(File.read(path)).to eq(fixture)
    end

    it "should update the lastchg field" do
      Date.expects(:today).returns Date.new(2013,5,12) # 15837 days after 1970-01-01
      write_fixture <<FIXTURE
before:seriously:15315:0:99999:7:::
fakeval:seriously:15629:0:99999:7:::
fakevalish:seriously:15315:0:99999:7:::
after:seriously:15315:0:99999:7:::
FIXTURE
      provider.password = "totally"
      expect(File.read(path)).to eq <<EOT
before:seriously:15315:0:99999:7:::
fakeval:totally:15837:0:99999:7:::
fakevalish:seriously:15315:0:99999:7:::
after:seriously:15315:0:99999:7:::
EOT
    end
  end

  describe "#shadow_entry" do
    it "should return the line for the right user" do
      File.stubs(:readlines).returns(["someuser:!:10:5:20:7:1::\n", "fakeval:*:20:10:30:7:2::\n", "testuser:*:30:15:40:7:3::\n"])
      expect(provider.shadow_entry).to eq(["fakeval", "*", "20", "10", "30", "7", "2", "", ""])
    end
  end

  describe "#password_max_age" do
    it "should return a maximum age number" do
      File.stubs(:readlines).returns(["fakeval:NP:12345:0:50::::\n"])
      expect(provider.password_max_age).to eq("50")
    end

    it "should return -1 for no maximum" do
      File.stubs(:readlines).returns(["fakeval:NP:12345::::::\n"])
      expect(provider.password_max_age).to eq(-1)
    end

    it "should return -1 for no maximum when failed attempts are present" do
      File.stubs(:readlines).returns(["fakeval:NP:12345::::::3\n"])
      expect(provider.password_max_age).to eq(-1)
    end
  end

  describe "#password_min_age" do
    it "should return a minimum age number" do
      File.stubs(:readlines).returns(["fakeval:NP:12345:10:50::::\n"])
      expect(provider.password_min_age).to eq("10")
    end

    it "should return -1 for no minimum" do
      File.stubs(:readlines).returns(["fakeval:NP:12345::::::\n"])
      expect(provider.password_min_age).to eq(-1)
    end

    it "should return -1 for no minimum when failed attempts are present" do
      File.stubs(:readlines).returns(["fakeval:NP:12345::::::3\n"])
      expect(provider.password_min_age).to eq(-1)
    end
  end
end
