require 'spec_helper'
require 'puppet/pops'

describe Puppet::Pops::LabelProvider do
  class TestLabelProvider
    include Puppet::Pops::LabelProvider
  end

  let(:labeler) { TestLabelProvider.new }

  it "prefixes words that start with a vowel with an 'an'" do
    expect(labeler.a_an('owl')).to eq('an owl')
  end

  it "prefixes words that start with a consonant with an 'a'" do
    expect(labeler.a_an('bear')).to eq('a bear')
  end

  it "prefixes non-word characters with an 'a'" do
    expect(labeler.a_an('[] expression')).to eq('a [] expression')
  end

  it "ignores a single quote leading the word" do
    expect(labeler.a_an("'owl'")).to eq("an 'owl'")
  end

  it "ignores a double quote leading the word" do
    expect(labeler.a_an('"owl"')).to eq('an "owl"')
  end

  it "capitalizes the indefinite article for a word when requested" do
    expect(labeler.a_an_uc('owl')).to eq('An owl')
  end

  it "raises an error when missing a character to work with" do
    expect {
      labeler.a_an('"')
    }.to raise_error(Puppet::DevError, /<"> does not appear to contain a word/)
  end

  it "raises an error when given an empty string" do
    expect {
      labeler.a_an('')
    }.to raise_error(Puppet::DevError, /<> does not appear to contain a word/)
  end
end
