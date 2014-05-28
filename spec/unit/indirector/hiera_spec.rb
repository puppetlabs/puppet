require 'spec_helper'
require 'puppet/data_binding'
require 'puppet/indirector/hiera'
require 'hiera/backend'

describe Puppet::Indirector::Hiera do

  module Testing
    module DataBinding
      class Hiera < Puppet::Indirector::Hiera
      end
    end
  end

  it_should_behave_like "Hiera indirection", Testing::DataBinding::Hiera, my_fixture_dir
end

