# frozen_string_literal: true

require "syntax_tree"

module Phlexing
  class Formatter
    attr_accessor :options

    def self.call(...)
      new(...).call
    end

    def initialize(source, max: nil, options: Options.new)
      @source = source.to_s.dup
      @max = max || options.max_line_length || 80
      @options = options
    end

    def call
      SyntaxTree.format(@source, @max).strip
    rescue SyntaxTree::Parser::ParseError, NoMethodError => e
      raise e if options.raise_errors?

      @source
    end
  end
end
