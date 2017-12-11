#! /usr/bin/env ruby
require 'spec_helper'
require 'puppet_spec/compiler'
require 'puppet/parser/functions'
require 'matchers/containment_matchers'
require 'matchers/resource'
require 'matchers/include_in_order'
require 'unit/functions/shared'


describe 'The "require" function' do
  include PuppetSpec::Compiler
  include ContainmentMatchers
  include Matchers::Resource

  before(:each) do
    compiler  = Puppet::Parser::Compiler.new(Puppet::Node.new("foo"))
    @scope = compiler.topscope
  end

  it 'includes a class that is not already included' do
    catalog = compile_to_catalog(<<-MANIFEST)
      class required {
        notify { "required": }
      }
      require required
    MANIFEST

    expect(catalog.classes).to include("required")
  end

  it 'sets the require attribute on the requiring resource' do
    catalog = compile_to_catalog(<<-MANIFEST)
      class required {
        notify { "required": }
      }
      class requiring {
        require required
      }
      include requiring
    MANIFEST

    requiring = catalog.resource("Class", "requiring")
    expect(requiring["require"]).to be_instance_of(Array)
    expect(requiring["require"][0]).to be_instance_of(Puppet::Resource)
    expect(requiring["require"][0].to_s).to eql("Class[Required]")
  end

  it 'appends to the require attribute on the requiring resource if it already has requirements' do
    catalog = compile_to_catalog(<<-MANIFEST)

      class required { }
      class also_required { }

      class requiring {
        require required
        require also_required
      }
      include requiring
    MANIFEST

    requiring = catalog.resource("Class", "requiring")
    expect(requiring["require"]).to be_instance_of(Array)
    expect(requiring["require"][0]).to be_instance_of(Puppet::Resource)
    expect(requiring["require"][0].to_s).to eql("Class[Required]")
    expect(requiring["require"][1]).to be_instance_of(Puppet::Resource)
    expect(requiring["require"][1].to_s).to eql("Class[Also_required]")
  end

  it "includes the class when using a fully qualified anchored name" do
    catalog = compile_to_catalog(<<-MANIFEST)
      class required {
        notify { "required": }
      }
      require ::required
    MANIFEST

    expect(catalog.classes).to include("required")
  end

  it_should_behave_like 'all functions transforming relative to absolute names', :require
  it_should_behave_like 'an inclusion function, regardless of the type of class reference,', :require
  it_should_behave_like 'an inclusion function, when --tasks is on,', :require

end
