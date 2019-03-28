shared_examples_for "a file_serving model" do
  include PuppetSpec::Files

  describe "#indirection" do
    localpath = PuppetSpec::Files.make_absolute("/etc/sudoers")
    localurl = "file://" + localpath

    before :each do
      # Never connect to the network, no matter what
      allow_any_instance_of(described_class.indirection.terminus(:rest).class).to receive(:find)
    end

    describe "when running the apply application" do
      before :each do
        Puppet[:default_file_terminus] = 'file_server'
      end

      {
       localpath => :file,
       localurl => :file,
       "puppet:///modules/foo/bar"       => :file_server,
       "puppet://server/modules/foo/bar" => :rest,
      }.each do |key, terminus|
        it "should use the #{terminus} terminus when requesting #{key.inspect}" do
          expect_any_instance_of(described_class.indirection.terminus(terminus).class).to receive(:find)

          described_class.indirection.find(key)
        end
      end
    end

    describe "when running another application" do
      before :each do
        Puppet[:default_file_terminus] = 'rest'
      end

      {
       localpath => :file,
       localurl => :file,
       "puppet:///modules/foo/bar"       => :rest,
       "puppet://server/modules/foo/bar" => :rest,
      }.each do |key, terminus|
        it "should use the #{terminus} terminus when requesting #{key.inspect}" do
          expect_any_instance_of(described_class.indirection.terminus(terminus).class).to receive(:find)

          described_class.indirection.find(key)
        end
      end
    end
  end
end
