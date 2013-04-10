require 'puppet'
require 'spec_helper'
require 'puppet_spec/compiler'

require 'unit/parser/methods/shared'

describe 'the collect method' do
  include PuppetSpec::Compiler

  before :each do
    Puppet[:parser] = "future"
  end

  context "using future parser" do
    context "in Ruby style should be callable as" do
      it 'collect on an array (multiplying each value by 2)' do
        catalog = compile_to_catalog(<<-MANIFEST)
          $a = [1,2,3]
          $a.collect {|$x| $x*2}.foreach {|$v| 
            file { "/file_$v": ensure => present }
          }
        MANIFEST

        catalog.resource(:file, "/file_2")['ensure'].should == 'present'
        catalog.resource(:file, "/file_4")['ensure'].should == 'present'
        catalog.resource(:file, "/file_6")['ensure'].should == 'present'
      end

      it 'collect on a hash selecting keys' do
        catalog = compile_to_catalog(<<-MANIFEST)
        $a = {'a'=>1,'b'=>2,'c'=>3}
        $a.collect {|$x| $x[0]}.foreach {|$k| 
            file { "/file_$k": ensure => present }
          }
        MANIFEST

        catalog.resource(:file, "/file_a")['ensure'].should == 'present'
        catalog.resource(:file, "/file_b")['ensure'].should == 'present'
        catalog.resource(:file, "/file_c")['ensure'].should == 'present'
      end
      it 'foreach on a hash selecting value' do
        catalog = compile_to_catalog(<<-MANIFEST)
        $a = {'a'=>1,'b'=>2,'c'=>3}
        $a.collect {|$x| $x[1]}.foreach {|$k| 
            file { "/file_$k": ensure => present }
          }
        MANIFEST

        catalog.resource(:file, "/file_1")['ensure'].should == 'present'
        catalog.resource(:file, "/file_2")['ensure'].should == 'present'
        catalog.resource(:file, "/file_3")['ensure'].should == 'present'
      end
    end
    context "in Java style should be callable as" do
      shared_examples_for 'java style' do
        it 'collect on an array (multiplying each value by 2)' do
          catalog = compile_to_catalog(<<-MANIFEST)
            $a = [1,2,3]
            $a.collect |$x| #{farr}{ $x*2}.foreach |$v| #{farr}{ 
              file { "/file_$v": ensure => present }
            }
          MANIFEST

          catalog.resource(:file, "/file_2")['ensure'].should == 'present'
          catalog.resource(:file, "/file_4")['ensure'].should == 'present'
          catalog.resource(:file, "/file_6")['ensure'].should == 'present'
        end

        it 'collect on a hash selecting keys' do
          catalog = compile_to_catalog(<<-MANIFEST)
          $a = {'a'=>1,'b'=>2,'c'=>3}
          $a.collect |$x| #{farr}{ $x[0]}.foreach |$k| #{farr}{ 
              file { "/file_$k": ensure => present }
            }
          MANIFEST

          catalog.resource(:file, "/file_a")['ensure'].should == 'present'
          catalog.resource(:file, "/file_b")['ensure'].should == 'present'
          catalog.resource(:file, "/file_c")['ensure'].should == 'present'
        end

        it 'foreach on a hash selecting value' do
          catalog = compile_to_catalog(<<-MANIFEST)
          $a = {'a'=>1,'b'=>2,'c'=>3}
          $a.collect |$x| #{farr} {$x[1]}.foreach |$k|#{farr}{ 
              file { "/file_$k": ensure => present }
            }
          MANIFEST

          catalog.resource(:file, "/file_1")['ensure'].should == 'present'
          catalog.resource(:file, "/file_2")['ensure'].should == 'present'
          catalog.resource(:file, "/file_3")['ensure'].should == 'present'
        end
      end
      describe 'without fat arrow' do
        it_should_behave_like 'java style' do
          let(:farr) { '' }
        end
      end
      describe 'with fat arrow' do
        it_should_behave_like 'java style' do
          let(:farr) { '=>' }
        end
      end
    end
  end

  it_should_behave_like 'all iterative functions argument checks', 'collect'
  it_should_behave_like 'all iterative functions hash handling', 'collect'
end
