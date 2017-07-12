module ConfigHound

  # Expand variables
  #
  module Interpolation

    extend self

    def expand(input, root = input, seen = Set.new)
      Context.new(root).expand(input)
    end

    # Interpolation context
    #
    class Context

      def initialize(root, seen = Set.new)
        @root = root
        @seen = seen.freeze
      end

      attr_reader :root
      attr_reader :seen

      def expand(input)
        case input
        when Hash
          expand_hash(input)
        when Array
          input.map { |v| expand(v) }
        when /\A<\(([\w.]+)\)>\Z/
          evaluate_expression($1)
        when /<\([\w.]+\)>/
          input.gsub(/<\(([\w.]+)\)>/) do
            evaluate_expression($1)
          end
        else
          input
        end
      end

      private

      def expand_hash(input)
        input.each_with_object({}) do |(k,v), a|
          a[k] = expand(v)
        end
      end

      def evaluate_expression(expr)
        if seen.include?(expr)
          details = seen.map { |e| "<(#{e})>" }.join(", ")
          raise CircularReferenceError, "circular reference: #{details}"
        end
        words = expr.split(".")
        expansion = root.dig(*words)
        if expansion.nil?
          raise ReferenceError, "cannot resolve reference: <(#{expr})>"
        end
        subcontext = Context.new(root, seen + [expr])
        subcontext.expand(expansion)
      end

    end

    class ReferenceError < StandardError; end
    class CircularReferenceError < ReferenceError; end

  end

end
