#! /usr/bin/env ruby
require 'spec_helper'

require 'puppet/parameter/path'

[false, true].each do |arrays|
  describe "Puppet::Parameter::Path with arrays #{arrays}" do
    it_should_behave_like "all path parameters", :path, :array => arrays do
      # The new type allows us a test that is guaranteed to go direct to our
      # validation code, without passing through any "real type" overrides or
      # whatever on the way.
      Puppet::Type.newtype(:test_puppet_parameter_path) do
        newparam(:path, :parent => Puppet::Parameter::Path, :arrays => arrays) do
          isnamevar
          accept_arrays arrays
        end
      end

      def instance(path)
        Puppet::Type.type(:test_puppet_parameter_path).new(:path => path)
      end
    end
  end
end
