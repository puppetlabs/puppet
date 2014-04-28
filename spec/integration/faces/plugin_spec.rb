require 'spec_helper'
require 'puppet/face'
require 'puppet/file_serving/metadata'
require 'puppet/file_serving/content'
require 'puppet/indirector/memory'

describe Puppet::Face[:plugin, '0.0.1'] do
  INDIRECTORS = [
    Puppet::Indirector::FileMetadata,
    Puppet::Indirector::FileContent,
  ]

  INDIRECTED_CLASSES = [
    Puppet::FileServing::Metadata,
    Puppet::FileServing::Content,
    Puppet::Node::Facts,
  ]

  INDIRECTORS.each do |indirector|
    class indirector::Memory < Puppet::Indirector::Memory
      def find(request)
        model.new('/dev/null', { 'type' => 'directory' })
      end
    end
  end

  before do
    FileUtils.mkdir(Puppet[:vardir])
    @termini_classes = {}
    INDIRECTED_CLASSES.each do |indirected|
      @termini_classes[indirected] = indirected.indirection.terminus_class
      indirected.indirection.terminus_class = :memory
    end
  end

  after do
    FileUtils.rmdir(File.join(Puppet[:vardir],'lib'))
    FileUtils.rmdir(File.join(Puppet[:vardir],'facts.d'))
    FileUtils.rmdir(Puppet[:vardir])
    INDIRECTED_CLASSES.each do |indirected|
      indirected.indirection.terminus_class = @termini_classes[indirected]
      indirected.indirection.termini.clear
    end
  end

  it "processes a download request without logging errors" do
    Puppet[:trace] = true
    result = subject.download
    expect(result).to eq([File.join(Puppet[:vardir],'facts.d')])
    expect(@logs.select { |l| l.level == :err }).to eq([])
  end
end
