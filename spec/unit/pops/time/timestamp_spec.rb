require 'spec_helper'
require 'puppet/pops'

module Puppet::Pops
  module Time
    describe 'Timestamp' do
      it 'Does not loose microsecond precision when converted to/from String' do
        ts = Timestamp.new(1495789430910161286)
        expect(Timestamp.parse(ts.to_s)).to eql(ts)
      end
    end
  end
end
