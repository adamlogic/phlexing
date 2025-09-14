# frozen_string_literal: true

require "syntax_tree"

module Phlexing
  class RubyAnalyzer
    attr_accessor :ivars, :locals, :idents, :calls, :consts, :instance_methods, :includes, :options

    def self.call(source)
      new.analyze(source)
    end

    def initialize(options: Options.new)
      @options = options
      @ivars = Set.new
      @locals = Set.new
      @idents = Set.new
      @calls = Set.new
      @consts = Set.new
      @instance_methods = Set.new
      @includes = Set.new
      @visitor = Visitor.new(self)
    end

    def analyze(source)
      code = extract_ruby_from_erb(source.to_s)

      analyze_ruby(code)
    end

    def analyze_ruby(code)
      # Avoid "invalid yield" exception from SyntaxTree
      code.gsub!(/\b(?<!\.)yield\b/, "nil")
      options.debug("BEFORE SyntaxTree.parse") { code }

      program = SyntaxTree.parse(code)
      @visitor.visit(program)

      self
    rescue SyntaxTree::Parser::ParseError, NoMethodError => e
      raise e if options.raise_errors?

      self
    end

    private

    def extract_ruby_from_erb(source)
      document = Parser.call(source, options: options)
      options.debug("AFTER Parser") { [document.inspect, document.errors].reject(&:blank?).join("\n\n") }

      lines = []

      lines << ruby_lines_from_erb_tags(document)
      lines << ruby_lines_from_erb_attributes(document)

      lines.join("\n")
    rescue StandardError => e
      raise e if options.raise_errors?

      ""
    end

    def ruby_lines_from_erb_tags(document)
      # deserialize erb that's been serialized to comments
      String.new.tap do |result|
        document.traverse do |node|
          if node.comment?
            _, erb_code = Parser.decode_erb_comment(node.text.to_s)
            erb_code.sub!(/^[=]/, "")
            result << erb_code
          end
        end
      end
    end

    def ruby_lines_from_erb_attributes(document)
      attributes = document.css("*").map(&:attributes)

      lines = []

      attributes.each do |pair|
        pair.select! { |name, _| name.start_with?("data-erb-") }

        pair.each do |_, value|
          Parser
            .call(value, options: options)
            .children
            .select { |child| child.is_a?(Nokogiri::XML::Node) && child.comment? }
            .each   { |child| lines << Parser.decode_erb_comment(child.text.strip).last }
        end
      end

      lines
    end
  end
end
