#! /usr/bin/env ruby
require 'spec_helper'

require 'puppet/parameter/package_options'

describe Puppet::Parameter::PackageOptions do
  let (:resource) { mock('resource') }
  let (:param)    { described_class.new(:resource => resource) }
  let (:arg)      { '/S' }
  let (:key)      { 'INSTALLDIR' }
  let (:value)    { 'C:/mydir' }

  context '#munge' do
    # The parser automatically converts single element arrays to just
    # a single element, why it does this is beyond me. See 46252b5bb8
    it 'should accept a string' do
      expect(param.munge(arg)).to eq([arg])
    end

    it 'should accept a hash' do
      expect(param.munge({key => value})).to eq([{key => value}])
    end

    it 'should accept an array of strings and hashes' do
      munged = param.munge([arg, {key => value}, '/NCRC', {'CONF' => 'C:\datadir'}])
      expect(munged).to eq([arg, {key => value}, '/NCRC', {'CONF' => 'C:\datadir'}])
    end

    it 'should quote strings' do
      expect(param.munge('arg one')).to eq(["\"arg one\""])
    end

    it 'should quote hash pairs' do
      munged = param.munge({'INSTALL DIR' => 'C:\Program Files'})
      expect(munged).to eq([{"\"INSTALL DIR\"" => "\"C:\\Program Files\""}])
    end

    it 'should reject symbols' do
      expect {
        param.munge([:symbol])
      }.to raise_error(Puppet::Error, /Expected either a string or hash of options/)
    end
  end
end
