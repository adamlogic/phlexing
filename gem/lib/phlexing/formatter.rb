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
      # Avoid "invalid yield" exception from SyntaxTree
      @source.gsub!(/\b(?<!\.)yield\b/, "__yield__")
      options.debug("BEFORE SyntaxTree.format") { @source }
      SyntaxTree.format(@source, @max).gsub(/\b__yield__\b/, "yield").strip
    rescue SyntaxTree::Parser::ParseError, NoMethodError => e
      raise e if options.raise_errors?

      @source
    end
  end
end
