require 'spec_helper'
require 'puppet/module_tool/applications'
require 'puppet_spec/modules'

describe Puppet::ModuleTool::Applications::Searcher do
  include PuppetSpec::Files

  describe "when searching" do
    let(:forge) { double('forge', :host => 'http://nowhe.re') }
    let(:searcher) do
      described_class.new('search_term', forge)
    end

    it "should return results from a forge query when successful" do
      results = 'mock results'
      expect(forge).to receive(:search).with('search_term').and_return(results)

      search_result = searcher.run
      expect(search_result).to eq({
        :result => :success,
        :answers => results,
      })
    end

    it "should return an error when the forge query throws an exception" do
      expect(forge).to receive(:search).with('search_term').and_raise(Puppet::Forge::Errors::ForgeError.new("something went wrong"))

      search_result = searcher.run
      expect(search_result).to eq({
        :result => :failure,
        :error => {
          :oneline   => 'something went wrong',
          :multiline => 'something went wrong',
        },
      })
    end
  end
end
