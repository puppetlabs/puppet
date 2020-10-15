require 'spec_helper'
require 'puppet/node'
require 'puppet/indirector/node/json'

describe Puppet::Node::Json do
  describe '#save' do
    subject(:indirection) { described_class.indirection }

    let(:env) { Puppet::Node::Environment.create(:testing, []) }
    let(:node) { Puppet::Node.new('node_name', :environment => env) }
    let(:file) { File.join(Puppet[:client_datadir], "node", "node_name.json") }

    before do
      indirection.terminus_class = :json
    end

    it 'is saves node details' do
      indirection.save(node)
    end

    it 'saves the instance of the node as JSON to disk' do
      indirection.save(node)
      json = Puppet::FileSystem.read(file, :encoding => 'bom|utf-8')
      content = Puppet::Util::Json.load(json)
      expect(content["name"]).to eq('node_name')
    end

    context 'when node cannot be saved' do
      it 'raises Errno::EISDIR' do
        FileUtils.mkdir_p(file)
        expect {
          indirection.save(node)
         }.to raise_error(Errno::EISDIR, /node_name.json/)
      end
    end
  end
end
