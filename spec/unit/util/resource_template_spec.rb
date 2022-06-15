require 'spec_helper'

require 'puppet/util/resource_template'

describe Puppet::Util::ResourceTemplate do
  describe "when initializing" do
    it "should fail if the template does not exist" do
      expect(Puppet::FileSystem).to receive(:exist?).with("/my/template").and_return(false)
      expect { Puppet::Util::ResourceTemplate.new("/my/template", double('resource')) }.to raise_error(ArgumentError)
    end

    it "should not create the ERB template" do
      expect(ERB).not_to receive(:new)
      expect(Puppet::FileSystem).to receive(:exist?).with("/my/template").and_return(true)
      Puppet::Util::ResourceTemplate.new("/my/template", double('resource'))
    end
  end

  describe "when evaluating" do
    before do
      allow(Puppet::FileSystem).to receive(:exist?).and_return(true)
      allow(Puppet::FileSystem).to receive(:read).and_return("eh")

      @template = double('template', :result => nil)
      allow(ERB).to receive(:new).and_return(@template)

      @resource = double('resource')
      @wrapper = Puppet::Util::ResourceTemplate.new("/my/template", @resource)
    end

    it "should set all of the resource's parameters as instance variables" do
      expect(@resource).to receive(:to_hash).and_return(:one => "uno", :two => "dos")
      expect(@template).to receive(:result) do |bind|
        expect(eval("@one", bind)).to eq("uno")
        expect(eval("@two", bind)).to eq("dos")
      end
      @wrapper.evaluate
    end

    it "should create a template instance with the contents of the file" do
      expect(Puppet::FileSystem).to receive(:read).with("/my/template", :encoding => 'utf-8').and_return("yay")
      expect(Puppet::Util).to receive(:create_erb).with("yay").and_return(@template)

      allow(@wrapper).to receive(:set_resource_variables)

      @wrapper.evaluate
    end

    it "should return the result of the template" do
      allow(@wrapper).to receive(:set_resource_variables)

      expect(@wrapper).to receive(:binding).and_return("mybinding")
      expect(@template).to receive(:result).with("mybinding").and_return("myresult")
      expect(@wrapper.evaluate).to eq("myresult")
    end
  end
end
