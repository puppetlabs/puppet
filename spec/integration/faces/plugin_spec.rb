require 'spec_helper'
require 'puppet/face'
require 'puppet/file_serving/metadata'
require 'puppet/file_serving/content'
require 'puppet/indirector/memory'

module PuppetFaceIntegrationSpecs
describe "Puppet plugin face" do
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
    FileUtils.mkdir(File.join(Puppet[:vardir], 'lib'))
    FileUtils.mkdir(File.join(Puppet[:vardir], 'facts.d'))
    FileUtils.mkdir(File.join(Puppet[:vardir], 'locales'))
    @termini_classes = {}
    INDIRECTED_CLASSES.each do |indirected|
      @termini_classes[indirected] = indirected.indirection.terminus_class
      indirected.indirection.terminus_class = :memory
    end
  end

  after do
    INDIRECTED_CLASSES.each do |indirected|
      indirected.indirection.terminus_class = @termini_classes[indirected]
      indirected.indirection.termini.clear
    end
  end

  def init_cli_args_and_apply_app(args = ["download"])
    Puppet::Application.find(:plugin).new(stub('command_line', :subcommand_name => :plugin, :args => args))
  end

  it "processes a download request" do
    app = init_cli_args_and_apply_app
    expect do
      expect {
        app.run
      }.to exit_with(0)
    end.to have_printed(/No plugins downloaded/)
  end
end
end
