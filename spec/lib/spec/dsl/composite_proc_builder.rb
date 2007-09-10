module Spec
  module DSL
    class CompositeProcBuilder < Array
      def initialize(callbacks=[])
        push(*callbacks)
      end

      def proc(&error_handler)
        parts = self
        errors = []
        Proc.new do
          result = parts.collect do |part|
            begin
              if part.is_a?(UnboundMethod)
                part.bind(self).call
              else
                instance_eval(&part)
              end
            rescue Exception => e
              if error_handler
                error_handler.call(e)
              else
                errors << e
              end
            end
          end
          raise errors.first unless errors.empty?
          result
        end
      end
    end
  end
end
