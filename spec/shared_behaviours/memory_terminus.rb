shared_examples_for "A Memory Terminus" do
  it "should find no instances by default" do
    expect(@searcher.find(@request)).to be_nil
  end

  it "should be able to find instances that were previously saved" do
    @searcher.save(@request)
    expect(@searcher.find(@request)).to equal(@instance)
  end

  it "should replace existing saved instances when a new instance with the same name is saved" do
    @searcher.save(@request)
    two = stub 'second', :name => @name
    trequest = stub 'request', :key => @name, :instance => two
    @searcher.save(trequest)
    expect(@searcher.find(@request)).to equal(two)
  end

  it "should be able to remove previously saved instances" do
    @searcher.save(@request)
    @searcher.destroy(@request)
    expect(@searcher.find(@request)).to be_nil
  end

  it "should fail when asked to destroy an instance that does not exist" do
    expect { @searcher.destroy(@request) }.to raise_error(ArgumentError)
  end
end
