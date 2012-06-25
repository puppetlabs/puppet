#!/usr/bin/env rspec

shared_examples_for "Puppet::FileServing::Files" do |indirection|
  %w[find search].each do |method|
    let(:request) { Puppet::Indirector::Request.new(indirection, method, 'foo') }

    before :each do
      # Stub this so we can set the :name setting
      Puppet::Util::Settings::ReadOnly.stubs(:include?)
    end

    describe "##{method}" do
      it "should proxy to file terminus if the path is absolute" do
        request.key = make_absolute('/tmp/foo')

        described_class.indirection.terminus(:file).class.any_instance.expects(method).with(request)

        subject.send(method, request)
      end

      it "should proxy to file terminus if the protocol is file" do
        request.protocol = 'file'

        described_class.indirection.terminus(:file).class.any_instance.expects(method).with(request)

        subject.send(method, request)
      end

      describe "when the protocol is puppet" do
        before :each do
          request.protocol = 'puppet'
        end

        describe "and a server is specified" do
          before :each do
            request.server = 'puppet_server'
          end

          it "should proxy to rest terminus if we're 'apply'" do
            Puppet[:name] = 'apply'

            described_class.indirection.terminus(:rest).class.any_instance.expects(method).with(request)

            subject.send(method, request)
          end

          it "should proxy to rest terminus if we aren't 'apply'" do
            Puppet[:name] = 'not_apply'

            described_class.indirection.terminus(:rest).class.any_instance.expects(method).with(request)

            subject.send(method, request)
          end
        end

        describe "and no server is specified" do
          before :each do
            request.server = nil
          end

          it "should proxy to file_server if we're 'apply'" do
            Puppet[:name] = 'apply'

            described_class.indirection.terminus(:file_server).class.any_instance.expects(method).with(request)

            subject.send(method, request)
          end

          it "should proxy to rest if we're not 'apply'" do
            Puppet[:name] = 'not_apply'

            described_class.indirection.terminus(:rest).class.any_instance.expects(method).with(request)

            subject.send(method, request)
          end
        end
      end
    end
  end
end
