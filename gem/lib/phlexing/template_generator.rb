# frozen_string_literal: true

require "nokogiri"

module Phlexing
  class TemplateGenerator
    using Refinements::StringRefinements

    include Helpers
    include PlainBufferHelpers

    attr_accessor :converter, :out, :options

    def self.call(converter, source)
      new(converter).call(source)
    end

    def initialize(converter)
      @converter = converter
      @options = @converter.options
      @out = StringIO.new
    end

    def call(source)
      @analyzer = RubyAnalyzer.new(options: options)
      @analyzer.analyze(source)

      options.debug("BEFORE Parser") { source }

      document = Parser.call(source, options: options)
      options.debug("AFTER Parser") { [document.inspect, document.errors].reject(&:blank?).join("\n\n") }
      handle_node(document)
      flush_plain!

      options.debug("BEFORE Formatter") { out.string.strip }

      Formatter.call(out.string.strip, options: options)
    rescue StandardError => e
      raise e if options.raise_errors?

      out.string.strip
    end

    def handle_text_output(text)
      output("plain", text)
    end

    def handle_erb_comment_node(node, content)
      kind, erb_content = Parser.decode_erb_comment(content)

      if kind == "loud"
        handle_loud_erb_node(node, erb_content)
      else
        handle_silent_erb_node(node, erb_content)
      end
    end

    def handle_html_comment_output(text)
      output("comment", braces(quote(escape_parens(text))))
    end

    def handle_erb_comment_output(text)
      output("#", text)
    end

    def handle_erb_unsafe_output(text)
      output("unsafe_raw", text)
    end

    def handle_output(text)
      output("", unescape(text))
    end

    def handle_attributes(node)
      return "" if node.attributes.keys.none?

      attributes = []

      node.attribute_nodes.each do |attribute|
        attributes << handle_attribute(attribute)
      end

      parens(attributes.join(", "))
    end

    def handle_attribute(attribute)
      if attribute.name.start_with?(/data-erb-(\d+)+/)
        handle_erb_interpolation_in_tag(attribute)
      elsif attribute.name.start_with?("data-erb-")
        handle_erb_attribute_output(attribute)
      else
        handle_html_attribute_output(attribute)
      end
    end

    def handle_html_attribute_output(attribute)
      String.new.tap { |s|
        s << arg(attribute.name.underscore)
        if attribute.value.blank? && !attribute.to_html.include?("=")
          # handling boolean attributes
          # eg. <input required> => input(required: true)
          s << "true"
        else
          s << quote(escape_parens(attribute.value))
        end
      }
    end

    def handle_erb_attribute_output(attribute)
      String.new.tap { |s|
        s << arg(attribute.name.delete_prefix("data-erb-").underscore)

        s << if attribute.value.start_with?("<%=") && attribute.value.scan("<%").one? && attribute.value.end_with?("%>")
          value = unwrap_erb(attribute.value)
          value.include?(" ") ? parens(value) : value
        else
          transformed = Parser.call(attribute.value, options: options)
          attribute = StringIO.new

          transformed.children.each do |node|
            case node
            when Nokogiri::XML::Text
              attribute << escape_parens(node.text)
            when Nokogiri::XML::Comment
              kind, code = Parser.decode_erb_comment(node.text)
              code.strip!

              if kind == "loud"
                attribute << interpolate(code)
              else
                attribute << interpolate("#{code} && nil")
              end
            end
          end

          quote(attribute.string)
        end
      }
    end

    def handle_erb_interpolation_in_tag(attribute)
      "**#{parens("#{unwrap_erb(unescape(attribute.value))}: true")}"
    end

    def handle_erb_safe_node(node, erb_content = nil)
      erb_content ||= node.text

      if siblings?(node) && string_output?(erb_content) && !output_helper?(erb_content)
        handle_text_output(erb_content.strip)
      else
        handle_output(erb_content.strip)
      end
    end

    def handle_text_node(node)
      text = node.text

      if text.squish.empty? && text.length.positive?
        output(whitespace, blank_line: false) unless %w[table thead tbody tfoot tr].include?(node.parent&.name)

        text.strip!
      end

      return if text.length.zero?

      text = quote(escape_parens(text))

      if siblings?(node)
        handle_text_output(text)
      else
        handle_output(text)
      end
    end

    def handle_html_element_node(node, level)
      flush_plain!

      out << tag_name(node)
      out << handle_attributes(node)

      params = node.name == "svg" ? options.svg_param : nil

      if node.children.any?
        block(params) { handle_children(node, level) }
      end

      out << newline
    end

    def handle_loud_erb_node(node, erb_content = nil)
      erb_content ||= node.text

      if erb_content.start_with?("=")
        handle_erb_unsafe_output(erb_content.from(1).strip)
      else
        handle_erb_safe_node(node, erb_content)
      end
    end

    def handle_silent_erb_node(node, erb_content = nil)
      erb_content ||= node.text

      if erb_content.start_with?("#")
        handle_erb_comment_output(erb_content.from(1).strip)
      else
        output(newline)
        handle_output(erb_content)
      end
    end

    def handle_html_comment_node(node)
      comment = node.text.strip

      if comment.start_with?("PHLEXING:ERB:")
        handle_erb_comment_node(node, comment)
      else
        handle_html_comment_output(comment)
      end
    end

    def handle_element_node(node, level)
      handle_html_element_node(node, level)
      out << newline if level == 1 || options.blank_line_between_children?
    end

    def handle_svg_node(node, level)
      node.children.each do |child|
        child.traverse do |subchild|
          subchild.name = SVG_ELEMENTS[subchild.name] if SVG_ELEMENTS.key?(subchild.name)
          subchild.name = subchild.name.prepend("#{options.svg_param}.") # rubocop:disable Style/RedundantSelfAssignment
        end
      end

      whitespace_before = options.whitespace
      options.whitespace = false

      handle_element_node(node, level)

      options.whitespace = whitespace_before
    end

    def handle_document_node(node, level)
      handle_children(node, level)
    end

    def handle_children(node, level)
      node.children.each do |child|
        handle_node(child, level + 1)
      end

      flush_plain! # ensure trailing sibling text is emitted before leaving the block
    end

    def handle_node(node, level = 0)
      case node
      in Nokogiri::XML::Text
        handle_text_node(node)
      in Nokogiri::XML::Element
        if node.name == "svg"
          handle_svg_node(node, level)
        else
          handle_element_node(node, level)
        end
      in Nokogiri::HTML4::Document | Nokogiri::HTML4::DocumentFragment | Nokogiri::HTML5::DocumentFragment | Nokogiri::XML::DTD
        handle_document_node(node, level)
      in Nokogiri::XML::Comment
        handle_html_comment_node(node)
      end
    end

    def output_helper?(content)
      word = content.strip.scan(/^\w+/)[0]
      @analyzer.output_helpers.include?(word)
    end
  end
end
