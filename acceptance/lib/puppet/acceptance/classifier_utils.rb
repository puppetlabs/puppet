require 'httparty'
require 'tempfile'
require 'stringio'
require 'uuidtools'
require 'json'
require 'pp'

module Puppet
  module Acceptance
    module ClassifierUtils
      DEFAULT_GROUP_ID = "00000000-0000-4000-8000-000000000000"
      SSL_PORT = 4433
      PREFIX = "/classifier-api"

      # Keep track of our local tmpdirs for cleanup
      def self.tmpdirs
        @classifier_utils_tmpdirs ||= []
      end

      # PE creates a "Production environment" group during installation which
      # all nodes are a member of by default.  This method just looks up this
      # group and returns its uuid so that other methods may reference it.
      def get_production_environment_group_uuid
        step "Get classifier groups so we can locate the 'Production environment' group"
        response = classifier_handle.get("/v1/groups")
        assert_equal(200, response.code, "Unable to get classifer groups: #{response.body}")

        groups_json = response.body
        groups = JSON.parse(groups_json)

        if production_environment = groups.find { |g| g['name'] == 'Production environment' }
          production_environment['id']
        else
          nil
        end
      end

      # Create a Classifier Group which by default will apply to all of the passed
      # nodes.  The Group will merge in the passed group_hash which will be converted
      # into the json body for a Classifier PUT /v1/groups/:id request.
      #
      # A teardown body is registered to delete the created group at the end of the test.
      #
      # @returns String the created uuid for the group.
      def create_group_for_nodes(nodes, group_hash)
        group_uuid = UUIDTools::UUID.random_create()
        response = nil

        teardown do
          step "Deleting group #{group_uuid}" do
            response = classifier_handle.delete("/v1/groups/#{group_uuid}")
            assert_equal(204, response.code, "Failed to delete group #{group_uuid}, #{response.code}:#{response.body}")
          end if response && response.code == 201
        end

        teardown do
          step "Cleaning up classifier certs on test host" do
            cleanup_local_classifier_certs
          end
        end

        hostnames = nodes.map { |n| n.hostname }
        step "Add group #{group_uuid} for #{hostnames.join(", ")}"
        rule = hostnames.inject(["or"]) do |r,name|
          r << ["~", "name", name]
          r
        end
        # In order to override the environment for test nodes, we need the
        # groups we create to be a child of this "Production environment" group,
        # otherwise we get a classification error from the conflicting groups.
        parent = get_production_environment_group_uuid || Puppet::Acceptance::ClassifierUtils::DEFAULT_GROUP_ID 
        body = {
          "description" => "A classification group for the following acceptance test nodes: (#{hostnames.join(", ")})",
          "parent" => parent,
          "rule" => rule,
          "classes" => {}
        }.merge group_hash
        response = classifier_handle.put("/v1/groups/#{group_uuid}", :body => body.to_json)

        assert_equal(201, response.code, "Unexpected response code: #{response.code}, #{response.body}")

        return group_uuid
      end

      # Creates a group which allows the given nodes to specify their own environments.
      # Will be torn down at the end of the test.
      def classify_nodes_as_agent_specified(nodes)
        create_group_for_nodes(nodes, {
          "name" => "Agent Specified Test Nodes",
          "environment" => "agent-specified",
          "environment_trumps" => true,
          "description" => "The following acceptance suite nodes (#{nodes.map { |n| n.hostname }.join(", ")}) expect to be able to specify their environment for tesing purposes.",
        })
      end

      def classify_nodes_as_agent_specified_if_classifer_present
        classifier_node = false
        begin
          classifier_node = find_only_one(:classifier)
        rescue Beaker::DSL::Outcomes::FailTest
        end

        if classifier_node || master.is_pe?
          classify_nodes_as_agent_specified(agents)
        end
      end

      def classifier_host
        find_only_one(:classifier)
      rescue Beaker::DSL::Outcomes::FailTest
        # fallback to master since currently the sqautils genconfig does not recognize
        # a classifier role.
        master
      end

      def master_cert
        @master_cert ||= on(master, "cat `puppet config print hostcert`", :silent => true).stdout
      end

      def master_key
        @master_key ||= on(master, "cat `puppet config print hostprivkey`", :silent => true).stdout
      end

      def master_ca_cert_file
        unless @ca_cert_file
          ca_cert = on(master, "cat `puppet config print localcacert`", :silent => true).stdout
          cert_dir = Dir.mktmpdir("pe_classifier_certs")
          Puppet::Acceptance::ClassifierUtils.tmpdirs << cert_dir

          @ca_cert_file = File.join(cert_dir, "cacert.pem")
          # RFC 1421 states PEM is 7-bit ASCII https://tools.ietf.org/html/rfc1421
          File.open(@ca_cert_file, "w:ASCII") do |f|
            f.write(ca_cert)
          end
        end
        @ca_cert_file
      end

      def cleanup_local_classifier_certs
        Puppet::Acceptance::ClassifierUtils.tmpdirs.each do |d|
          FileUtils.rm_rf(d)
        end
      end

      def clear_classifier_utils_cache
        @master_cert = nil
        @master_key = nil
        @ca_cert_file = nil
        @classifier_handle = nil
      end

      def classifier_handle(options = {})
        unless @classifier_handle
          server = options[:server] || classifier_host.reachable_name
          port = options[:port] || SSL_PORT
          prefix = options[:prefix] || PREFIX
          cert = options[:cert] || master_cert
          key = options[:key] || master_key
          ca_cert_file = options[:ca_cert_file] || master_ca_cert_file
          logger = options[:logger] || self.logger

          # HTTParty performs a lot of configuration at the class level.
          # This is inconvenient for our needs because we don't have the
          # server/cert info available at the time the class is loaded.  I'm
          # sidestepping this by generating an anonymous class on the fly when
          # the test code actually requests a handle to the classifier.
          @classifier_handle = Class.new do
            include HTTParty
            extend Classifier
            @debugout = StringIO.new
            @logger = logger
            base_uri("https://#{server}:#{port}#{prefix}")
            debug_output(@debugout)
            headers({'Content-Type' => 'application/json'})
            pem(cert + key)
            ssl_ca_file(ca_cert_file)
          end
        end
        @classifier_handle
      end

      # Handle logging
      module Classifier

        [:head, :get, :post, :put, :delete].each do |method|
          define_method(method) do |*args, &block|
            log_output do
              super(*args, &block)
            end
          end
        end

        private

        # Ensure that the captured debugging output is logged to Beaker.
        def log_output
          yield
        ensure
          @debugout.rewind
          @debugout.each_line { |l| @logger.info(l) }
          @debugout.truncate(0)
        end
      end
    end
  end
end
