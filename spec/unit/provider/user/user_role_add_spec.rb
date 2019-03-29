require 'spec_helper'
require 'puppet_spec/files'
require 'tempfile'

describe Puppet::Type.type(:user).provider(:user_role_add), :unless => Puppet::Util::Platform.windows? do
  include PuppetSpec::Files
  let(:resource) { Puppet::Type.type(:user).new(:name => 'myuser', :managehome => false, :allowdupe => false) }
  let(:provider) { described_class.new(resource) }

  before do
    allow(resource).to receive(:should).and_return("fakeval")
    allow(resource).to receive(:should).with(:keys).and_return(Hash.new)
    allow(resource).to receive(:[]).and_return("fakeval")
  end

  describe "#command" do
    before do
      klass = double("provider")
      allow(klass).to receive(:superclass)
      allow(klass).to receive(:command).with(:foo).and_return("userfoo")
      allow(klass).to receive(:command).with(:role_foo).and_return("rolefoo")
      allow(provider).to receive(:class).and_return(klass)
    end

    it "should use the command if not a role and ensure!=role" do
      allow(provider).to receive(:is_role?).and_return(false)
      allow(provider).to receive(:exists?).and_return(false)
      allow(resource).to receive(:[]).with(:ensure).and_return(:present)
      allow(provider.class).to receive(:foo)
      expect(provider.command(:foo)).to eq("userfoo")
    end

    it "should use the role command when a role" do
      allow(provider).to receive(:is_role?).and_return(true)
      expect(provider.command(:foo)).to eq("rolefoo")
    end

    it "should use the role command when !exists and ensure=role" do
      allow(provider).to receive(:is_role?).and_return(false)
      allow(provider).to receive(:exists?).and_return(false)
      allow(resource).to receive(:[]).with(:ensure).and_return(:role)
      expect(provider.command(:foo)).to eq("rolefoo")
    end
  end

  describe "#transition" do
    it "should return the type set to whatever is passed in" do
      expect(provider).to receive(:command).with(:modify).and_return("foomod")
      provider.transition("bar").include?("type=bar")
    end
  end

  describe "#create" do
    before do
      allow(provider).to receive(:password=)
    end

    it "should use the add command when the user is not a role" do
      allow(provider).to receive(:is_role?).and_return(false)
      expect(provider).to receive(:addcmd).and_return("useradd")
      expect(provider).to receive(:run).at_least(:once)
      provider.create
    end

    it "should use transition(normal) when the user is a role" do
      allow(provider).to receive(:is_role?).and_return(true)
      expect(provider).to receive(:transition).with("normal")
      expect(provider).to receive(:run)
      provider.create
    end

    it "should set password age rules" do
      resource = Puppet::Type.type(:user).new :name => "myuser", :password_min_age => 5, :password_max_age => 10, :password_warn_days => 15, :provider => :user_role_add
      provider = described_class.new(resource)
      allow(provider).to receive(:user_attributes)
      allow(provider).to receive(:execute)
      expect(provider).to receive(:execute).with([anything, "-n", 5, "-x", 10, '-w', 15, "myuser"])
      provider.create
    end
  end

  describe "#destroy" do
    it "should use the delete command if the user exists and is not a role" do
      allow(provider).to receive(:exists?).and_return(true)
      allow(provider).to receive(:is_role?).and_return(false)
      expect(provider).to receive(:deletecmd)
      expect(provider).to receive(:run)
      provider.destroy
    end

    it "should use the delete command if the user is a role" do
      allow(provider).to receive(:exists?).and_return(true)
      allow(provider).to receive(:is_role?).and_return(true)
      expect(provider).to receive(:deletecmd)
      expect(provider).to receive(:run)
      provider.destroy
    end
  end

  describe "#create_role" do
    it "should use the transition(role) if the user exists" do
      allow(provider).to receive(:exists?).and_return(true)
      allow(provider).to receive(:is_role?).and_return(false)
      expect(provider).to receive(:transition).with("role")
      expect(provider).to receive(:run)
      provider.create_role
    end

    it "should use the add command when role doesn't exists" do
      allow(provider).to receive(:exists?).and_return(false)
      expect(provider).to receive(:addcmd)
      expect(provider).to receive(:run)
      provider.create_role
    end
  end

  describe "with :allow_duplicates" do
    before do
      allow(resource).to receive(:allowdupe?).and_return(true)
      allow(provider).to receive(:is_role?).and_return(false)
      allow(provider).to receive(:execute)
      allow(resource).to receive(:system?).and_return(false)
      expect(provider).to receive(:execute).with(include("-o"), any_args)
    end

    it "should add -o when the user is being created" do
      allow(provider).to receive(:password=)
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
          expect(provider).to receive(:user_attributes)
          provider.send(val)
        end

        it "should get the #{val} attribute" do
          attributes = double("attributes")
          expect(attributes).to receive(:[]).with(val)
          allow(provider).to receive(:user_attributes).and_return(attributes)
          provider.send(val)
        end
      end
    end
  end

  describe "#keys" do
    it "should get the user_attributes" do
      expect(provider).to receive(:user_attributes)
      provider.keys
    end

    it "should call removed_managed_attributes" do
      allow(provider).to receive(:user_attributes).and_return({ :type => "normal", :foo => "something" })
      expect(provider).to receive(:remove_managed_attributes)
      provider.keys
    end

    it "should removed managed attribute (type, auths, roles, etc)" do
      allow(provider).to receive(:user_attributes).and_return({ :type => "normal", :foo => "something" })
      expect(provider.keys).to eq({ :foo => "something" })
    end
  end

  describe "#add_properties" do
    it "should call build_keys_cmd" do
      allow(resource).to receive(:should).and_return("")
      expect(resource).to receive(:should).with(:keys).and_return({ :foo => "bar" })
      expect(provider).to receive(:build_keys_cmd).and_return([])
      provider.add_properties
    end

    it "should add the elements of the keys hash to an array" do
      allow(resource).to receive(:should).and_return("")
      expect(resource).to receive(:should).with(:keys).and_return({ :foo => "bar"})
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
      allow(provider).to receive(:is_role?).and_return(false)
    end

    it "should run a command" do
      expect(provider).to receive(:run)
      provider.keys=({})
    end

    it "should build the command" do
      allow(resource).to receive(:[]).with(:name).and_return("someuser")
      allow(provider).to receive(:command).and_return("usermod")
      expect(provider).to receive(:build_keys_cmd).and_return(["-K", "foo=bar"])
      expect(provider).to receive(:run).with(["usermod", "-K", "foo=bar", "someuser"], "modify attribute key pairs")
      provider.keys=({})
    end
  end

  describe "#password" do
    before do
      @array = double("array")
    end

    it "should readlines of /etc/shadow" do
      expect(File).to receive(:readlines).with("/etc/shadow").and_return([])
      provider.password
    end

    it "should reject anything that doesn't start with alpha numerics" do
      expect(@array).to receive(:reject).and_return([])
      allow(File).to receive(:readlines).with("/etc/shadow").and_return(@array)
      provider.password
    end

    it "should collect splitting on ':'" do
      allow(@array).to receive(:reject).and_return(@array)
      expect(@array).to receive(:collect).and_return([])
      allow(File).to receive(:readlines).with("/etc/shadow").and_return(@array)
      provider.password
    end

    it "should find the matching user" do
      allow(resource).to receive(:[]).with(:name).and_return("username")
      allow(@array).to receive(:reject).and_return(@array)
      allow(@array).to receive(:collect).and_return([["username", "hashedpassword"], ["someoneelse", "theirpassword"]])
      allow(File).to receive(:readlines).with("/etc/shadow").and_return(@array)
      expect(provider.password).to eq("hashedpassword")
    end

    it "should get the right password" do
      allow(resource).to receive(:[]).with(:name).and_return("username")
      allow(File).to receive(:readlines).with("/etc/shadow").and_return(["#comment", "   nonsense", "  ", "username:hashedpassword:stuff:foo:bar:::", "other:pword:yay:::"])
      expect(provider.password).to eq("hashedpassword")
    end
  end

  describe "#password=" do
    let(:path) { tmpfile('etc-shadow') }

    before :each do
      allow(provider).to receive(:target_file_path).and_return(path)
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
      expect(Date).to receive(:today).and_return(Date.new(2011,12,07))
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
      expect(Date).to receive(:today).and_return(Date.new(2013,5,12)) # 15837 days after 1970-01-01
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
      allow(File).to receive(:readlines).and_return(["someuser:!:10:5:20:7:1::\n", "fakeval:*:20:10:30:7:2::\n", "testuser:*:30:15:40:7:3::\n"])
      expect(provider.shadow_entry).to eq(["fakeval", "*", "20", "10", "30", "7", "2", "", ""])
    end
  end

  describe "#password_max_age" do
    it "should return a maximum age number" do
      allow(File).to receive(:readlines).and_return(["fakeval:NP:12345:0:50::::\n"])
      expect(provider.password_max_age).to eq("50")
    end

    it "should return -1 for no maximum" do
      allow(File).to receive(:readlines).and_return(["fakeval:NP:12345::::::\n"])
      expect(provider.password_max_age).to eq(-1)
    end

    it "should return -1 for no maximum when failed attempts are present" do
      allow(File).to receive(:readlines).and_return(["fakeval:NP:12345::::::3\n"])
      expect(provider.password_max_age).to eq(-1)
    end
  end

  describe "#password_min_age" do
    it "should return a minimum age number" do
      allow(File).to receive(:readlines).and_return(["fakeval:NP:12345:10:50::::\n"])
      expect(provider.password_min_age).to eq("10")
    end

    it "should return -1 for no minimum" do
      allow(File).to receive(:readlines).and_return(["fakeval:NP:12345::::::\n"])
      expect(provider.password_min_age).to eq(-1)
    end

    it "should return -1 for no minimum when failed attempts are present" do
      allow(File).to receive(:readlines).and_return(["fakeval:NP:12345::::::3\n"])
      expect(provider.password_min_age).to eq(-1)
    end
  end

  describe "#password_warn_days" do
    it "should return a warn days number" do
      allow(File).to receive(:readlines).and_return(["fakeval:NP:12345:10:50:30:::\n"])
      expect(provider.password_warn_days).to eq("30")
    end

    it "should return -1 for no warn days" do
      allow(File).to receive(:readlines).and_return(["fakeval:NP:12345::::::\n"])
      expect(provider.password_warn_days).to eq(-1)
    end

    it "should return -1 for no warn days when failed attempts are present" do
      allow(File).to receive(:readlines).and_return(["fakeval:NP:12345::::::3\n"])
      expect(provider.password_warn_days).to eq(-1)
    end
  end
end
