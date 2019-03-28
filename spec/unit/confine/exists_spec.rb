require 'spec_helper'

require 'puppet/confine/exists'

describe Puppet::Confine::Exists do
  before do
    @confine = Puppet::Confine::Exists.new("/my/file")
    @confine.label = "eh"
  end

  it "should be named :exists" do
    expect(Puppet::Confine::Exists.name).to eq(:exists)
  end
  
  it "should not pass if exists is nil" do
    confine = Puppet::Confine::Exists.new(nil)
    confine.label = ":exists => nil"
    expect(confine).to receive(:pass?).with(nil)
    expect(confine).not_to be_valid
  end

  it "should use the 'pass?' method to test validity" do
    expect(@confine).to receive(:pass?).with("/my/file")
    @confine.valid?
  end

  it "should return false if the value is false" do
    expect(@confine.pass?(false)).to be_falsey
  end

  it "should return false if the value does not point to a file" do
    expect(Puppet::FileSystem).to receive(:exist?).with("/my/file").and_return(false)
    expect(@confine.pass?("/my/file")).to be_falsey
  end

  it "should return true if the value points to a file" do
    expect(Puppet::FileSystem).to receive(:exist?).with("/my/file").and_return(true)
    expect(@confine.pass?("/my/file")).to be_truthy
  end

  it "should produce a message saying that a file is missing" do
    expect(@confine.message("/my/file")).to be_include("does not exist")
  end

  describe "and the confine is for binaries" do
    before do
      allow(@confine).to receive(:for_binary).and_return(true)
    end

    it "should use its 'which' method to look up the full path of the file" do
      expect(@confine).to receive(:which).and_return(nil)
      @confine.pass?("/my/file")
    end

    it "should return false if no executable can be found" do
      expect(@confine).to receive(:which).with("/my/file").and_return(nil)
      expect(@confine.pass?("/my/file")).to be_falsey
    end

    it "should return true if the executable can be found" do
      expect(@confine).to receive(:which).with("/my/file").and_return("/my/file")
      expect(@confine.pass?("/my/file")).to be_truthy
    end
  end

  it "should produce a summary containing all missing files" do
    allow(Puppet::FileSystem).to receive(:exist?).and_return(true)
    expect(Puppet::FileSystem).to receive(:exist?).with("/two").and_return(false)
    expect(Puppet::FileSystem).to receive(:exist?).with("/four").and_return(false)

    confine = Puppet::Confine::Exists.new %w{/one /two /three /four}
    expect(confine.summary).to eq(%w{/two /four})
  end

  it "should summarize multiple instances by returning a flattened array of their summaries" do
    c1 = double('1', :summary => %w{one})
    c2 = double('2', :summary => %w{two})
    c3 = double('3', :summary => %w{three})

    expect(Puppet::Confine::Exists.summarize([c1, c2, c3])).to eq(%w{one two three})
  end
end
