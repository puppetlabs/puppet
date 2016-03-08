require 'spec_helper'
require 'puppet/pops'

module Puppet::Pops
module Types
describe 'Puppet Type System' do
  let(:tf) { TypeFactory }
  context 'Integer type' do
    let!(:a) { tf.range(10, 20) }
    let!(:b) { tf.range(18, 28) }
    let!(:c) { tf.range( 2, 12) }
    let!(:d) { tf.range(12, 18) }
    let!(:e) { tf.range( 8, 22) }
    let!(:f) { tf.range( 8,  9) }
    let!(:g) { tf.range(21, 22) }
    let!(:h) { tf.range(30, 31) }
    let!(:i) { tf.float_range(1.0, 30.0) }
    let!(:j) { tf.float_range(1.0, 9.0) }

    context 'when testing if ranges intersect' do
      it 'detects an intersection when self is before its argument' do
        expect(a.intersect?(b)).to be_truthy
      end

      it 'detects an intersection when self is after its argument' do
        expect(a.intersect?(c)).to be_truthy
      end

      it 'detects an intersection when self covers its argument' do
        expect(a.intersect?(d)).to be_truthy
      end

      it 'detects an intersection when self equals its argument' do
        expect(a.intersect?(a)).to be_truthy
      end

      it 'detects an intersection when self is covered by its argument' do
        expect(a.intersect?(e)).to be_truthy
      end

      it 'does not consider an adjacent range to be intersecting' do
        [f, g].each {|x| expect(a.intersect?(x)).to be_falsey }
      end

      it 'does not consider an range that is apart to be intersecting' do
        expect(a.intersect?(h)).to be_falsey
      end

      it 'does not consider an overlapping float range to be intersecting' do
        expect(a.intersect?(i)).to be_falsey
      end
    end

    context 'when testing if ranges are adjacent' do
      it 'detects an adjacent type when self is after its argument' do
        expect(a.adjacent?(f)).to be_truthy
      end

      it 'detects an adjacent type when self is before its argument' do
        expect(a.adjacent?(g)).to be_truthy
      end

      it 'does not consider overlapping types to be adjacent' do
        [a, b, c, d, e].each { |x| expect(a.adjacent?(x)).to be_falsey }
      end

      it 'does not consider an range that is apart to be adjacent' do
        expect(a.adjacent?(h)).to be_falsey
      end

      it 'does not consider an adjacent float range to be adjancent' do
        expect(a.adjacent?(j)).to be_falsey
      end
    end

    context 'when merging ranges' do
      it 'will merge intersecting ranges' do
        expect(a.merge(b)).to eq(tf.range(10, 28))
      end

      it 'will merge adjacent ranges' do
        expect(a.merge(g)).to eq(tf.range(10, 22))
      end

      it 'will not merge ranges that are apart' do
        expect(a.merge(h)).to be_nil
      end

      it 'will not merge overlapping float ranges' do
        expect(a.merge(i)).to be_nil
      end

      it 'will not merge adjacent float ranges' do
        expect(a.merge(j)).to be_nil
      end
    end
  end

  context 'Float type' do
    let!(:a) { tf.float_range(10.0, 20.0) }
    let!(:b) { tf.float_range(18.0, 28.0) }
    let!(:c) { tf.float_range( 2.0, 12.0) }
    let!(:d) { tf.float_range(12.0, 18.0) }
    let!(:e) { tf.float_range( 8.0, 22.0) }
    let!(:f) { tf.float_range(30.0, 31.0) }
    let!(:g) { tf.range(1, 30) }

    context 'when testing if ranges intersect' do
      it 'detects an intersection when self is before its argument' do
        expect(a.intersect?(b)).to be_truthy
      end

      it 'detects an intersection when self is after its argument' do
        expect(a.intersect?(c)).to be_truthy
      end

      it 'detects an intersection when self covers its argument' do
        expect(a.intersect?(d)).to be_truthy
      end

      it 'detects an intersection when self equals its argument' do
        expect(a.intersect?(a)).to be_truthy
      end

      it 'detects an intersection when self is covered by its argument' do
        expect(a.intersect?(e)).to be_truthy
      end

      it 'does not consider an range that is apart to be intersecting' do
        expect(a.intersect?(f)).to be_falsey
      end

      it 'does not consider an overlapping integer range to be intersecting' do
        expect(a.intersect?(g)).to be_falsey
      end
    end

    context 'when merging ranges' do
      it 'will merge intersecting ranges' do
        expect(a.merge(b)).to eq(tf.float_range(10.0, 28.0))
      end

      it 'will not merge ranges that are apart' do
        expect(a.merge(f)).to be_nil
      end

      it 'will not merge overlapping integer ranges' do
        expect(a.merge(g)).to be_nil
      end
    end
  end

  context 'Optional type' do
    let!(:overlapping_ints) { tf.variant(tf.range(10, 20), tf.range(18, 28)) }
    let!(:optoptopt) { tf.optional(tf.optional(tf.optional(overlapping_ints))) }
    let!(:optnu) { tf.optional(tf.not_undef(overlapping_ints)) }

    context 'when normalizing' do
      it 'compacts optional in optional in optional to just optional' do
        expect(optoptopt.normalize).to eq(tf.optional(tf.range(10, 28)))
      end
    end

    it 'compacts NotUndef in Optional to just Optional' do
      expect(optnu.normalize).to eq(tf.optional(tf.range(10, 28)))
    end
  end

  context 'NotUndef type' do
    let!(:nununu) { tf.not_undef(tf.not_undef(tf.not_undef(tf.any))) }
    let!(:nuopt) { tf.not_undef(tf.optional(tf.any)) }

    context 'when normalizing' do
      it 'compacts NotUndef in NotUndef in NotUndef to just NotUndef' do
        expect(nununu.normalize).to eq(tf.not_undef(tf.any))
      end

      it 'compacts Optional in NotUndef to just NotUndef' do
        expect(nuopt.normalize).to eq(tf.not_undef(tf.any))
      end
    end
  end

  context 'Variant type' do
    let!(:overlapping_ints) { tf.variant(tf.range(10, 20), tf.range(18, 28)) }
    let!(:adjacent_ints) { tf.variant(tf.range(10, 20), tf.range(8, 9)) }
    let!(:mix_ints) { tf.variant(overlapping_ints, adjacent_ints) }
    let!(:overlapping_floats) { tf.variant(tf.float_range(10.0, 20.0), tf.float_range(18.0, 28.0)) }
    let!(:enums) { tf.variant(tf.enum('a', 'b'), tf.enum('b', 'c')) }
    let!(:patterns) { tf.variant(tf.pattern('a', 'b'), tf.pattern('b', 'c')) }
    let!(:with_undef) { tf.variant(tf.undef, tf.range(1,10)) }
    let!(:all_optional) { tf.variant(tf.optional(tf.range(1,10)), tf.optional(tf.range(11,20))) }
    let!(:groups) { tf.variant(mix_ints, overlapping_floats, enums, patterns, with_undef, all_optional) }

    context 'when normalizing contained types that' do
      it 'are overlapping ints, the result is a range' do
        expect(overlapping_ints.normalize).to eq(tf.range(10, 28))
      end

      it 'are adjacent ints, the result is a range' do
        expect(adjacent_ints.normalize).to eq(tf.range(8, 20))
      end

      it 'are mixed variants with adjacent and overlapping ints, the result is a range' do
        expect(mix_ints.normalize).to eq(tf.range(8, 28))
      end

      it 'are overlapping floats, the result is a float range' do
        expect(overlapping_floats.normalize).to eq(tf.float_range(10.0, 28.0))
      end

      it 'are enums, the result is an enum' do
        expect(enums.normalize).to eq(tf.enum('a', 'b', 'c'))
      end

      it 'are patterns, the result is a pattern' do
        expect(patterns.normalize).to eq(tf.pattern('a', 'b', 'c'))
      end

      it 'contains an Undef, the result is Optional' do
        expect(with_undef.normalize).to eq(tf.optional(tf.range(1,10)))
      end

      it 'are all Optional, the result is an Optional with normalized type' do
        expect(all_optional.normalize).to eq(tf.optional(tf.range(1,20)))
      end

      it 'can be normalized in groups, the result is a Variant containing the resulting normalizations' do
        expect(groups.normalize).to eq(tf.variant(
          tf.range(8, 28),
          tf.float_range(10.0, 28.0),
          tf.enum('a', 'b', 'c'),
          tf.pattern('a', 'b', 'c'),
          tf.optional(tf.range(1,20)))
        )
      end
    end
  end
end
end
end
