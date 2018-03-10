require 'puppet_spec/compiler'
require 'matchers/resource'

module PuppetSpec::Language
  extend RSpec::Matchers::DSL

  def produces(expectations)
    calledFrom = caller
    expectations.each do |manifest, resources|
      it "evaluates #{manifest} to produce #{resources}" do
        begin
          case resources
          when String
            node = Puppet::Node.new('specification')
            Puppet[:code] = manifest
            compiler = Puppet::Parser::Compiler.new(node)
            evaluator = Puppet::Pops::Parser::EvaluatingParser.new()

            # see lib/puppet/indirector/catalog/compiler.rb#filter
            catalog = compiler.compile.filter { |r| r.virtual? }

            compiler.send(:instance_variable_set, :@catalog, catalog)

            Puppet.override(:loaders => compiler.loaders) do
              expect(evaluator.evaluate_string(compiler.topscope, resources)).to eq(true)
            end
          when Array
            catalog = PuppetSpec::Compiler.compile_to_catalog(manifest)

            if resources.empty?
              base_resources = ["Class[Settings]", "Class[main]", "Stage[main]"]
              expect(catalog.resources.collect(&:ref) - base_resources).to eq([])
            else
              resources.each do |reference|
                if reference.is_a?(Array)
                  matcher = Matchers::Resource.have_resource(reference[0])
                  reference[1].each do |name, value|
                    matcher = matcher.with_parameter(name, value)
                  end
                else
                  matcher = Matchers::Resource.have_resource(reference)
                end

                expect(catalog).to matcher
              end
            end
          else
            raise "Unsupported creates specification: #{resources.inspect}"
          end
        rescue  Puppet::Error, RSpec::Expectations::ExpectationNotMetError => e
          # provide the backtrace from the caller, or it is close to impossible to find some originators
          e.set_backtrace(calledFrom)
          raise
        end
      end
    end
  end

  def fails(expectations)
    calledFrom = caller
    expectations.each do |manifest, pattern|
      it "fails to evaluate #{manifest} with message #{pattern}" do
        begin
        expect do
          PuppetSpec::Compiler.compile_to_catalog(manifest)
        end.to raise_error(Puppet::Error, pattern)
        rescue  RSpec::Expectations::ExpectationNotMetError => e
          # provide the backgrace from the caller, or it is close to impossible to find some originators
          e.set_backtrace(calledFrom)
          raise
        end
      end
    end
  end
end
