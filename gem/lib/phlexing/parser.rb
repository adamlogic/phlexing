# frozen_string_literal: true

require "nokogiri"
require "base64"

module Phlexing
  class Parser
    def self.call(source, options: Options.new)
      source = ERBTransformer.call(source)
      options.debug("AFTER ERBTransformer") { source }
      source = rewrite_erb_tags_as_comments(source)
      options.debug("AFTER rewrite_erb_tags_as_comments") { source }
      source = Minifier.call(source)
      options.debug("AFTER Minifier") { source }

      # Credit:
      # https://github.com/spree/deface/blob/6bf18df76715ee3eb3d0cd1b6eda822817ace91c/lib/deface/parser.rb#L105-L111
      #

      html_tag = /<html(( .*?(?:(?!>)[\s\S])*>)|>)/i
      head_tag = /<head(( .*?(?:(?!>)[\s\S])*>)|>)/i
      body_tag = /<body(( .*?(?:(?!>)[\s\S])*>)|>)/i

      if source =~ html_tag
        Nokogiri::HTML::Document.parse(source)
      elsif source =~ head_tag && source =~ body_tag
        Nokogiri::HTML::Document.parse(source).css("html").first
      elsif source =~ head_tag
        Nokogiri::HTML::Document.parse(source).css("head").first
      elsif source =~ body_tag
        Nokogiri::HTML::Document.parse(source).css("body").first
      else
        Nokogiri::HTML5::DocumentFragment.parse(source, context: "template", max_errors: 10)
      end
    end

    def self.rewrite_erb_tags_as_comments(source)
      source.gsub(%r{<erb([^>]*)>-?(.*?)(-?)</erb>}m) do
        attrs = Regexp.last_match(1)
        body  = Regexp.last_match(2).strip
        body << "\n" unless Regexp.last_match(3) == "-"
        kind  = attrs.include?("loud") ? "loud" : "silent"
        body = CGI.unescapeHTML(body)
        payload = Base64.strict_encode64(body)
        %(<!--PHLEXING:ERB:#{kind}:#{payload}-->)
      end
    end

    def self.decode_erb_comment(comment)
      # "PHLEXING:ERB:<kind>:<base64>"
      _, _, kind, encoded = comment.split(":", 4)
      [kind, Base64.decode64(encoded || "")]
    end
  end
end
