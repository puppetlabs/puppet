require 'spec_helper'
require 'puppet/pops'

describe 'the Puppet::Pops::Types::ClassLoader' do
  it 'should produce path alternatives for CamelCase classes' do
    expected_paths = ['puppet_x/some_thing', 'puppetx/something']
    # path_for_name method is private
    expect(Puppet::Pops::Types::ClassLoader.send(:paths_for_name, ['PuppetX', 'SomeThing'])).to include(*expected_paths)
  end
end
