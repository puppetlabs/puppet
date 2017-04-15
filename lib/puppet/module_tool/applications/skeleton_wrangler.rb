require 'pathname'
require 'tmpdir'

module Puppet::ModuleTool
  module Applications
    class SkeletonWrangler < Application

      def initialize(options = {})
        super(options)
      end

      def skeleton
        @skeleton ||= Skeleton.new
      end

      def run
        results = {}
        Puppet.notice "Fetching your skeletons..."
        results["Default Path"] = skeleton.default_path
        results["Custom Path"] = skeleton.custom_path
        results
      end

    end
  end
end
