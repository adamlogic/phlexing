# frozen_string_literal: true

module Phlexing
  module PlainBufferHelpers
    def plain_buffer
      @plain_buffer ||= []
    end

    def flush_plain!
      return if plain_buffer.empty?
      options.debug("plain buffer") { plain_buffer }

      merged = if plain_buffer.size == 1
        plain_buffer.first
      else
        string_contents = plain_buffer.map do |s|
          s = unwrap_string_literal(s)
          s = s.gsub('\\', '\\\\').gsub('"', '\"') unless s.start_with?("\#{")
          s
        end.join

        %("#{string_contents}")
      end

      # Write directly to avoid recursion through #output
      out << "plain "
      out << merged
      out << newline

      plain_buffer.clear
    end

    def unwrap_string_literal(str)
      case str.strip
      when /^%[(\[{|]/
        # %() / %[] / %{} / %||
        return str[2..-2]
      when /^["']/
        # "" / ''
        return str[1..-2]
      else
        # Fallback: treat as expression to interpolate
        "\#{#{str}}"
      end
    end
  end
end
