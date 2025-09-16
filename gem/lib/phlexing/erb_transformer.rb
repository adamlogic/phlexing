# frozen_string_literal: true

require "deface"

module Phlexing
  # Takes ERB and transforms it to Nokogiri-compatible HTML.
  class ERBTransformer
    def self.call(...)
      new(...).call
    end

    def initialize(source)
      @source = source.to_s.dup
    end

    def call
      serialize_preserved_elements
      remove_newlines
      strip_whitespace
      transform_erb_tags
      transform_template_tags
      deserialize_preserved_elements

      @source
    end

    private

    def serialize_preserved_elements
      tags = "(script|style|pre|textarea)"
      @source.gsub!(/<#{tags}.*?<\/#{tags}>/im) do |outer_html|
        payload = Base64.strict_encode64(outer_html)
        %(<!--PHLEXING:PRESERVED_ELEMENT:#{payload}-->)
      end
    end

    def deserialize_preserved_elements
      @source.gsub!(/<!--PHLEXING:PRESERVED_ELEMENT:(.*?)-->/im) do
        Base64.decode64(Regexp.last_match[1])
      end
    end

    def remove_newlines
      @source.tr!("\n\r", "")
    end

    def strip_whitespace
      @source.strip!
    end

    # Replace ERB tags with Nokogiri-compatible HTML.
    def transform_erb_tags
      @source = Deface::Parser.erb_markup!(@source)
    end

    # Phlex uses `template_tag` in place of `template` for `<template>` tags.
    def transform_template_tags
      @source.gsub!(/<template/i, "<template-tag")
      @source.gsub!(%r{</template}i, "</template-tag")
    end
  end
end
