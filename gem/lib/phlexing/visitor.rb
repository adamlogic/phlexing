# frozen_string_literal: true

require "syntax_tree"

module Phlexing
  class Visitor < SyntaxTree::Visitor
    using Refinements::StringRefinements
    include Helpers

    def initialize(analyzer)
      @analyzer = analyzer
      @node_stack = []
    end

    def analyze(node, allow_output_helpers: true)
      @allow_output_helpers = allow_output_helpers
      visit(node)
    end

    def visit(node)
      # track the node stack to determine if the current node is a top-level call
      @node_stack << node
      super
    ensure
      @node_stack.pop
    end

    def visit_ivar(node)
      @analyzer.ivars << node.value.from(1)
    end

    def visit_const(node)
      @analyzer.consts << node.value
    end

    def visit_command(node)
      unless rails_helper?(node.message.value)
        @analyzer.output_helpers << node.message.value
      end
      super
    end

    def visit_call(node)
      if node.receiver
        case node.receiver
        when SyntaxTree::VarRef
          value = node.receiver.value.value

          case node.receiver.value
          when SyntaxTree::IVar
            @analyzer.ivars << value.from(1)
          when SyntaxTree::Ident
            @analyzer.idents << value
          end

          @analyzer.calls << value

        when SyntaxTree::VCall
          case node.receiver.value
          when SyntaxTree::Ident
            @analyzer.calls << node.receiver.value.value
          end

        when SyntaxTree::Ident
          value = node.receiver.value.value.value

          @analyzer.idents << value unless value.ends_with?("?")
          @analyzer.calls << value

        when SyntaxTree::Const
          @analyzer.calls << node.receiver.value
        end

      elsif node.receiver.nil? && node.operator.nil?
        case node.message
        when SyntaxTree::Ident
          if node.message.value.end_with?("?") || node.child_nodes[3].is_a?(SyntaxTree::ArgParen)
            unless rails_helper?(node.message.value)
              # If the node is a method call at the top level, we should register it as an output helper.
              # If the node is an argument to another method or part of a conditional, we should register it as a value helper.
              # Examples:
              # some_helper? => output helper
              # some_helper => output helper
              # if some_helper? => value helper
              # some_caller(some_helper) => value helper
              name = node.message.value
              if @allow_output_helpers && @node_stack[-2].class.in?([NilClass, SyntaxTree::Program, SyntaxTree::Statements])
                @analyzer.output_helpers << name
              else
                @analyzer.value_helpers << name
              end
            end
            @analyzer.calls << node.message.value
          else
            @analyzer.idents << node.message.value
          end
        end
      end

      super
    end

    def visit_vcall(node)
      unless rails_helper?(node.value.value)
        @analyzer.locals << node.value.value
      end
    end

    def visit_ident(node)
      unless rails_helper?(node.value)
        @analyzer.idents << node.value
      end
    end

    private

    def rails_helper?(name)
      if known_rails_helpers.keys.include?(name)
        @analyzer.includes << known_rails_helpers[name]
        return true
      end

      if routes_helpers.map { |regex| name.scan(regex).any? }.reduce(:|)
        @analyzer.includes << "Phlex::Rails::Helpers::Routes"
        return true
      end

      false
    end
  end
end
