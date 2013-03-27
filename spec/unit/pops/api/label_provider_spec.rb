require 'spec_helper'
require 'puppet/pops/api/label_provider'

describe Puppet::Pops::API::LabelProvider do
  let(:labeler) { Puppet::Pops::API::LabelProvider.new }

  it "prefixes words that start with a vowel with an 'an'" do
    labeler.a_an('owl').should == 'an owl'
  end

  it "prefixes words that start with a consonant with an 'a'" do
    labeler.a_an('bear').should == 'a bear'
  end

  it "ignores a single quote leading the word" do
    labeler.a_an("'owl'").should == "an 'owl'"
  end

  it "ignores a double quote leading the word" do
    labeler.a_an('"owl"').should == 'an "owl"'
  end

  it "capitalizes the indefinite article for a word when requested" do
    labeler.a_an_uc('owl').should == 'An owl'
  end

  it "raises an error on a leading space" do
    expect {
      labeler.a_an(' owl')
    }.to raise_error(Puppet::DevError, /Cannot determine article for word starting with < >/)
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
