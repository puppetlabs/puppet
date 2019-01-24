require 'spec_helper'

provider_class = Puppet::Type.type(:mcx).provider(:mcxcontent)

# describe creates a new ExampleGroup object.
describe provider_class do
  # :each executes before each test.
  # :all executes once for the test group and before :each.
  before :each do
    # Create a mock resource
    @resource = double('resource')

    @provider = provider_class.new
    @attached_to = "/Users/foobar"
    @ds_path = "/Local/Default/Users/foobar"

    # A catch all; no parameters set
    allow(@resource).to receive(:[]).and_return(nil)

    # But set name, ensure and enable
    allow(@resource).to receive(:[]).with(:name).and_return(@attached_to)
    allow(@resource).to receive(:[]).with(:ensure).and_return(:present)
    allow(@resource).to receive(:ref).and_return("Mcx[#{@attached_to}]")

    # stub out the provider methods that actually touch the filesystem
    # or execute commands
    allow(@provider.class).to receive(:execute).and_return('')
    allow(@provider).to receive(:execute).and_return('')
    allow(@provider).to receive(:resource).and_return(@resource)
  end

  it "should have a create method." do
    expect(@provider).to respond_to(:create)
  end

  it "should have a destroy method." do
    expect(@provider).to respond_to(:destroy)
  end

  it "should have an exists? method." do
    expect(@provider).to respond_to(:exists?)
  end

  it "should have a content method." do
    expect(@provider).to respond_to(:content)
  end

  it "should have a content= method." do
    expect(@provider).to respond_to(:content=)
  end

  describe "when managing the resource" do
    it "should execute external command dscl from :create" do
      allow(@provider).to receive(:has_mcx?).and_return(false)
      expect(@provider.class).to receive(:dscl).and_return('').once
      @provider.create
    end

    it "deletes existing mcx prior to import from :create" do
      allow(@provider).to receive(:has_mcx?).and_return(true)
      expect(@provider.class).to receive(:dscl).with('localhost', '-mcxdelete', @ds_path, any_args()).once
      expect(@provider.class).to receive(:dscl).with('localhost', '-mcximport', @ds_path, any_args()).once
      @provider.create
    end

    it "should execute external command dscl from :destroy" do
      expect(@provider.class).to receive(:dscl).with('localhost', '-mcxdelete', @ds_path).and_return('').once
      @provider.destroy
    end

    it "should execute external command dscl from :exists?" do
      expect(@provider.class).to receive(:dscl).with('localhost', '-mcxexport', @ds_path).and_return('').once
      @provider.exists?
    end

    it "should execute external command dscl from :content" do
      expect(@provider.class).to receive(:dscl).with('localhost', '-mcxexport', @ds_path).and_return('')
      @provider.content
    end

    it "should execute external command dscl from :content=" do
      allow(@provider).to receive(:has_mcx?).and_return(false)
      expect(@provider.class).to receive(:dscl).and_return('').once
      @provider.content=''
    end

    it "deletes existing mcx prior to import from :content=" do
      allow(@provider).to receive(:has_mcx?).and_return(true)
      expect(@provider.class).to receive(:dscl).with('localhost', '-mcxdelete', @ds_path, any_args()).once
      expect(@provider.class).to receive(:dscl).with('localhost', '-mcximport', @ds_path, any_args()).once
      @provider.content=''
    end
  end

  describe "when creating and parsing the name for ds_type" do
    before :each do
      allow(@provider.class).to receive(:dscl).and_return('')
      allow(@resource).to receive(:[]).with(:name).and_return("/Foo/bar")
    end

    it "should not accept /Foo/bar" do
      expect { @provider.create }.to raise_error(MCXContentProviderException)
    end

    it "should accept /Foo/bar with ds_type => user" do
      allow(@resource).to receive(:[]).with(:ds_type).and_return("user")
      expect { @provider.create }.to_not raise_error
    end

    it "should accept /Foo/bar with ds_type => group" do
      allow(@resource).to receive(:[]).with(:ds_type).and_return("group")
      expect { @provider.create }.to_not raise_error
    end

    it "should accept /Foo/bar with ds_type => computer" do
      allow(@resource).to receive(:[]).with(:ds_type).and_return("computer")
      expect { @provider.create }.to_not raise_error
    end

    it "should accept :name => /Foo/bar with ds_type => computerlist" do
      allow(@resource).to receive(:[]).with(:ds_type).and_return("computerlist")
      expect { @provider.create }.to_not raise_error
    end
  end

  describe "when creating and :name => foobar" do
    before :each do
      allow(@provider.class).to receive(:dscl).and_return('')
      allow(@resource).to receive(:[]).with(:name).and_return("foobar")
    end

    it "should not accept unspecified :ds_type and :ds_name" do
      expect { @provider.create }.to raise_error(MCXContentProviderException)
    end

    it "should not accept unspecified :ds_type" do
      allow(@resource).to receive(:[]).with(:ds_type).and_return("user")
      expect { @provider.create }.to raise_error(MCXContentProviderException)
    end

    it "should not accept unspecified :ds_name" do
      allow(@resource).to receive(:[]).with(:ds_name).and_return("foo")
      expect { @provider.create }.to raise_error(MCXContentProviderException)
    end

    it "should accept :ds_type => user, ds_name => foo" do
      allow(@resource).to receive(:[]).with(:ds_type).and_return("user")
      allow(@resource).to receive(:[]).with(:ds_name).and_return("foo")
      expect { @provider.create }.to_not raise_error
    end

    it "should accept :ds_type => group, ds_name => foo" do
      allow(@resource).to receive(:[]).with(:ds_type).and_return("group")
      allow(@resource).to receive(:[]).with(:ds_name).and_return("foo")
      expect { @provider.create }.to_not raise_error
    end

    it "should accept :ds_type => computer, ds_name => foo" do
      allow(@resource).to receive(:[]).with(:ds_type).and_return("computer")
      allow(@resource).to receive(:[]).with(:ds_name).and_return("foo")
      expect { @provider.create }.to_not raise_error
    end

    it "should accept :ds_type => computerlist, ds_name => foo" do
      allow(@resource).to receive(:[]).with(:ds_type).and_return("computerlist")
      allow(@resource).to receive(:[]).with(:ds_name).and_return("foo")
      expect { @provider.create }.to_not raise_error
    end

    it "should not accept :ds_type => bogustype, ds_name => foo" do
      allow(@resource).to receive(:[]).with(:ds_type).and_return("bogustype")
      allow(@resource).to receive(:[]).with(:ds_name).and_return("foo")
      expect { @provider.create }.to raise_error(MCXContentProviderException)
    end
  end

  describe "when gathering existing instances" do
    it "should define an instances class method." do
      expect(@provider.class).to respond_to(:instances)
    end

    it "should call external command dscl -list /Local/Default/<ds_type> on each known ds_type" do
      expect(@provider.class).to receive(:dscl).with('localhost', '-list', "/Local/Default/Users").and_return('')
      expect(@provider.class).to receive(:dscl).with('localhost', '-list', "/Local/Default/Groups").and_return('')
      expect(@provider.class).to receive(:dscl).with('localhost', '-list', "/Local/Default/Computers").and_return('')
      expect(@provider.class).to receive(:dscl).with('localhost', '-list', "/Local/Default/ComputerLists").and_return('')
      @provider.class.instances
    end
  end
end
