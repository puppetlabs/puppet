require File.join(File.dirname(__FILE__),'../../acceptance_spec_helper.rb')
require 'puppet/acceptance/puppet_type_test_tools.rb'
require 'beaker/dsl/assertions'
require 'beaker/result'

module Puppet
  module Acceptance

    describe 'PuppetTypeTestTools' do
      include PuppetTypeTestTools
      include Beaker::DSL::Assertions
      include Beaker

      context '#generate_manifest' do
        it 'takes a single hash' do
          expect(generate_manifest({:type => 'fake'})).to match(/^fake{"fake_\w{8}":}$/)
        end
        it 'takes an array' do
          expect(generate_manifest([{:type => 'fake'}])).to match(/^fake{"fake_\w{8}":}$/)
        end
        it 'generates empty puppet code (assertion-only instance)' do
          expect(generate_manifest({:fake => 'fake'})).to eql('')
        end
        it 'puts a namevar in the right place' do
          expect(generate_manifest({:type => 'fake', :parameters =>
                                    {:namevar => 'blah'}})).to match(/^fake{"blah":}$/)
        end
        it 'retains puppet code in a namevar' do
          expect(generate_manifest({:type => 'fake', :parameters =>
                                    {:namevar => "half_${interpolated}_puppet_namevar"}})).
          to match(/^fake{"half_\${interpolated}_puppet_namevar":}$/)
        end
        it 'places pre_code before the type' do
          expect(generate_manifest({:type => 'fake', :pre_code => '$some = puppet_code'})).
            to match(/^\$some = puppet_code\nfake{"fake_\w{8}":}$/m)
        end
        it 'places multiple, arbitrary parameters' do
          expect(generate_manifest({:type => 'fake', :parameters =>
                                    {:someprop => "function(call)", :namevar => "blah", :someparam => 2}})).
          to match(/^fake{"blah":someprop => function\(call\),someparam => 2,}$/)
        end
      end

      context '#generate_assertions' do
        it 'takes a single hash' do
          expect(generate_assertions({:assertions => {:fake => 'matcher'}}))
            .to match(/^fake\("matcher", result\.stdout, '"matcher"'\)$/)
        end
        it 'takes an array' do
          expect(generate_assertions([{:assertions => {:fake => 'matcher'}}]))
            .to match(/^fake\("matcher", result\.stdout, '"matcher"'\)$/)
        end
        it 'generates empty assertions (puppet-code only instance)' do
          expect(generate_assertions({:type => 'no assertions'})).to eql('')
        end
        it 'generates arbitrary assertions' do
          expect(generate_assertions({:assertions => [{:fake => 'matcher'},
                                                      {:other => 'othermatch'}]}))
            .to match(/^fake\("matcher", result\.stdout, '"matcher"'\)\nother\("othermatch", result.stdout, '"othermatch"'\)$/m)
        end
        it 'can give a regex to assertions' do
          expect(generate_assertions({:assertions => {:fake => /matcher/}}))
            .to match(/^fake\(\/matcher\/, result\.stdout, '\/matcher\/'\)$/)
        end
        it 'allows multiple of one assertion type' do
          expect(generate_assertions({:assertions => {:fake => ['matcher','othermatch']}}))
            .to match(/^fake\("matcher", result\.stdout, '"matcher"'\)\nfake\("othermatch", result.stdout, '"othermatch"'\)$/)
        end
        it 'allows multiple assertion_types with multiple values' do
          expect(generate_assertions({:assertions => [{:fake => ['matcher','othermatch']},
                                                      {:fake2 => ['matcher2','othermatch2']}]}))
            .to match(/^fake\("matcher", result\.stdout, '"matcher"'\)\nfake\("othermatch", result.stdout, '"othermatch"'\)\nfake2\("matcher2", result.stdout, '"matcher2"'\)\nfake2\("othermatch2", result.stdout, '"othermatch2"'\)\n$/)
        end
        context 'expect_failure' do
          it 'generates arbitrary assertion' do
            expect(generate_assertions({:assertions => {:expect_failure => {:fake => 'matcher'}}}))
              .to match(/^expect_failure '' do\nfake\(.*\)\nend$/)
          end
          it 'allows multiple of one assertion type' do
            expect(generate_assertions({:assertions => {:expect_failure => {:fake => ['matcher','othermatch']}}}))
              .to match(/^expect_failure '' do\nfake\(.*\)\nfake\(.*\)\nend$/)
          end
          it 'allows multiple assertion_types' do
            pending 'ack! requires recursion :-('
            #expect(generate_assertions({:assertions => {:expect_failure => [{:fake => 'matcher'},{:fake2 => 'matcher2'}]}}))
              #.to match(/^expect_failure '' do\nfake\(.*\)\nfake2\(.*\)\nend$/)
          end
          it 'allows multiple assertion_types with an expect_failure on one' do
            expect(generate_assertions({:assertions => [{:expect_failure => {:fake => 'matcher'}}, {:fake2 => 'matcher2'}]}))
              .to match(/^expect_failure '' do\nfake\(.*\)\nend\nfake2\(.*\)$/)
          end
          it 'allows custom expect_failure messages' do
            expect(generate_assertions({:assertions => {:expect_failure => {:fake => 'matcher', :message => 'oh noes, this should fail but pass'}}}))
              .to match(/^expect_failure 'oh noes, this should fail but pass' do\nfake\(.*\)\nend$/)
          end
        end
        it 'allow custom assertion messages'
      end

      context 'run_assertions' do
      #def run_assertions(assertions = '', result)
        it 'takes a string result' do
          expect(run_assertions('assert_match("yes please", result.stdout)', 'yes please')).to be true
        end
        let(:result) {Beaker::Result.new('host','command')}
        it 'takes a beaker "type" Result' do
          result.stdout = 'yes please'
          expect(run_assertions('assert_match("yes please", result.stdout)', result)).to be true
        end
        it 'runs a bunch of assertions' do
          result.stdout = 'yes please'
          expect(run_assertions("assert_match('yes please', result.stdout)\nrefute_match('blah', result.stdout)", result)).to be false
        end
        it 'fails assertions' do
          pending 'why doesnt this work?'
          result.stdout = 'yes please'
          expect(run_assertions('assert_match("blah", result.stdout)', result)).to raise_error
        end
        context 'exceptions' do
          #rescue RuntimeError, SyntaxError => e
          it 'puts the assertion code, raises error' do
            pending 'why doesnt this work?'
            expect(run_assertions('assert_match("blah") }', result)).to raise_error
          end
        end
      end

    end

  end
end
