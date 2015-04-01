require 'spec_helper'
require 'puppet/pops'

describe 'Puppet::Pops::Validation::Diagnostic' do

  # Mocks a SourcePosAdapter as it is used in these use cases
  # of a Diagnostic
  #
  class MockSourcePos
    attr_reader :offset
    def initialize(offset)
      @offset = offset
    end
  end

  it "computes equal hash value ignoring arguments" do
    issue = Puppet::Pops::Issues::DIV_BY_ZERO
    source_pos = MockSourcePos.new(10)
    d1 = Puppet::Pops::Validation::Diagnostic.new(:warning, issue, "foo", source_pos, {:foo => 10})
    d2 = Puppet::Pops::Validation::Diagnostic.new(:warning, issue, "foo", source_pos.clone, {:bar => 20})
    expect(d1.hash).to eql(d2.hash)
  end

  it "computes non equal hash value for different severities" do
    issue = Puppet::Pops::Issues::DIV_BY_ZERO
    source_pos = MockSourcePos.new(10)
    d1 = Puppet::Pops::Validation::Diagnostic.new(:warning, issue, "foo", source_pos, {})
    d2 = Puppet::Pops::Validation::Diagnostic.new(:error, issue, "foo", source_pos.clone, {})
    expect(d1.hash).to_not eql(d2.hash)
  end

  it "computes non equal hash value for different offsets" do
    issue = Puppet::Pops::Issues::DIV_BY_ZERO
    source_pos1 = MockSourcePos.new(10)
    source_pos2 = MockSourcePos.new(11)
    d1 = Puppet::Pops::Validation::Diagnostic.new(:warning, issue, "foo", source_pos1, {})
    d2 = Puppet::Pops::Validation::Diagnostic.new(:warning, issue, "foo", source_pos2, {})
    expect(d1.hash).to_not eql(d2.hash)
  end

  it "can be used in a set" do
    the_set = Set.new()
    issue = Puppet::Pops::Issues::DIV_BY_ZERO
    source_pos = MockSourcePos.new(10)
    d1 = Puppet::Pops::Validation::Diagnostic.new(:warning, issue, "foo", source_pos, {})
    d2 = Puppet::Pops::Validation::Diagnostic.new(:warning, issue, "foo", source_pos.clone, {})
    d3 = Puppet::Pops::Validation::Diagnostic.new(:error, issue, "foo", source_pos.clone, {})
    expect(the_set.add?(d1)).to_not be_nil
    expect(the_set.add?(d2)).to be_nil
    expect(the_set.add?(d3)).to_not be_nil
  end

end

describe "Puppet::Pops::Validation::SeverityProducer" do
  it 'sets default severity given in initializer' do
    producer = Puppet::Pops::Validation::SeverityProducer.new(:warning)
    expect(producer.severity(Puppet::Pops::Issues::DIV_BY_ZERO)).to be(:warning)
  end

  it 'sets default severity to :error if not given' do
    producer = Puppet::Pops::Validation::SeverityProducer.new()
    expect(producer.severity(Puppet::Pops::Issues::DIV_BY_ZERO)).to be(:error)
  end

end
