#! /usr/bin/env ruby
require 'spec_helper'
require 'puppet/pops'

module Puppet::Pops
describe 'MergeStrategy' do
  context 'deep merge' do
    it 'does not mutate the source of a merge' do
      a = { 'a' => { 'b' => 'va' }, 'c' => 2 }
      b = { 'a' => { 'b' => 'vb' }, 'b' => 3}
      c = MergeStrategy.strategy(:deep).merge(a, b);
      expect(a).to eql({ 'a' => { 'b' => 'va' }, 'c' => 2 })
      expect(b).to eql({ 'a' => { 'b' => 'vb' }, 'b' => 3 })
      expect(c).to eql({ 'a' => { 'b' => 'va' }, 'b' => 3, 'c' => 2 })
    end
  end
end
end
