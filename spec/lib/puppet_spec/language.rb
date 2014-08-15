require 'puppet_spec/compiler'
require 'matchers/resource'

module PuppetSpec::Language
  def produces(expectations)
    expectations.each do |manifest, resources|
      it "evaluates #{manifest} to produce #{resources}" do
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
      end
    end
  end

  def fails(expectations)
    expectations.each do |manifest, pattern|
      it "fails to evaluate #{manifest} with message #{pattern}" do
        expect do
          PuppetSpec::Compiler.compile_to_catalog(manifest)
        end.to raise_error(Puppet::Error, pattern)
      end
    end
  end
end
