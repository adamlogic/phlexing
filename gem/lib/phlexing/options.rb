# frozen_string_literal: true

module Phlexing
  class Options
    attr_accessor :component, :component_name, :parent_component, :whitespace, :svg_param, :template_name, :raise_errors, :max_line_length, :blank_line_between_children

    alias_method :whitespace?, :whitespace
    alias_method :component?, :component
    alias_method :raise_errors?, :raise_errors
    alias_method :blank_line_between_children?, :blank_line_between_children

    def initialize(
      component: false,
      component_name: "Component",
      parent_component: "Phlex::HTML",
      whitespace: true,
      svg_param: "s",
      template_name: "view_template",
      raise_errors: false,
      max_line_length: 80,
      blank_line_between_children: false)
      @component = component
      @component_name = safe_constant_name(component_name)
      @parent_component = safe_constant_name(parent_component)
      @whitespace = whitespace
      @svg_param = svg_param
      @template_name = template_name
      @raise_errors = raise_errors
      @max_line_length = max_line_length
      @blank_line_between_children = blank_line_between_children
    end

    def safe_constant_name(name)
      name = name.to_s

      if name[0] == "0" || name[0].to_i != 0
        "A#{name}"
      else
        name
      end
    end
  end
end
