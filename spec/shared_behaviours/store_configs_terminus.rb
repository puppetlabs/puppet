shared_examples_for "a StoreConfigs terminus" do
  before :each do
    Puppet[:storeconfigs] = true
    Puppet[:storeconfigs_backend] = "store_configs_testing"
  end

  api = [:find, :search, :save, :destroy, :head]

  api.each do |name|
    it { is_expected.to respond_to(name) }
  end

  it "should fail if an invalid backend is configured" do
    Puppet[:storeconfigs_backend] = "synergy"
    expect { subject }.to raise_error(ArgumentError, /could not find terminus synergy/i)
  end

  it "should wrap the declared backend" do
    expect(subject.target.class.name).to eq(:store_configs_testing)
  end
end
