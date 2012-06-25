module Puppet
  module Util
    class RunMode
      def initialize(name)
        @name = name.to_sym
      end

      @@run_modes = Hash.new {|h, k| h[k] = RunMode.new(k)}

      attr :name

      def self.[](name)
        @@run_modes[name]
      end

      def master?
        name == :master
      end

      def agent?
        name == :agent
      end

      def user?
        name == :user
      end


      def run_dir
        "$vardir/run"
      end

      def log_dir
        "$vardir/log"
      end

    end
  end
end
