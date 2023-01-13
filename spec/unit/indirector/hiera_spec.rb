require 'spec_helper'
require 'puppet/data_binding'
require 'puppet/indirector/hiera'

begin
  require 'hiera/backend'
rescue LoadError => e
  Puppet.warning(_("Unable to load Hiera 3 backend: %{message}") % {message: e.message})
end

describe Puppet::Indirector::Hiera, :if => Puppet.features.hiera? do

  module Testing
    module DataBinding
      class Hiera < Puppet::Indirector::Hiera
      end
    end
  end

  it_should_behave_like "Hiera indirection", Testing::DataBinding::Hiera, my_fixture_dir
end

