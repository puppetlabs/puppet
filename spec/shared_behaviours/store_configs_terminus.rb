shared_examples_for "a StoreConfigs terminus" do
  before :each do
    Puppet[:storeconfigs] = true
    Puppet[:storeconfigs_backend] = "store_configs_testing"
  end

  api = [:find, :search, :save, :destroy, :head]

  api.each do |name|
    it { should respond_to name }
  end

  it "should fail if an invalid backend is configured" do
    Puppet[:storeconfigs_backend] = "synergy"
    expect { subject }.to raise_error ArgumentError, /could not find terminus synergy/i
  end

  it "should wrap the declared backend" do
    subject.target.class.name.should == :store_configs_testing
  end
end
