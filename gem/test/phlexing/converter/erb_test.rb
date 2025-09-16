# frozen_string_literal: true

require_relative "../../test_helper"

class Phlexing::Converter::ErbTest < Minitest::Spec
  it "ERB method call using <% and %>" do
    html = %(<div><% some_local %></div>)

    expected = <<~PHLEX.strip
      div { some_local }
    PHLEX

    assert_phlex_template expected, html do
      assert_locals "some_local"
    end
  end

  it "ERB method call using <%= and %>" do
    html = %(<div><%= some_local %></div>)

    expected = <<~PHLEX.strip
      div { some_local }
    PHLEX

    assert_phlex_template expected, html do
      assert_locals "some_local"
    end
  end

  it "ERB method call using <%- and -%>" do
    html = %(<div><%- some_local -%></div>)

    expected = <<~PHLEX.strip
      div { some_local }
    PHLEX

    assert_phlex_template expected, html do
      assert_locals "some_local"
    end
  end

  it "ERB method call using <%- and %>" do
    html = %(<div><%- some_local %></div>)

    expected = <<~PHLEX.strip
      div { some_local }
    PHLEX

    assert_phlex_template expected, html do
      assert_locals "some_local"
    end
  end

  it "ERB no method call using <%# and %>" do
    html = %(<div><%# some_local %></div>)

    expected = <<~PHLEX.strip
      div do # some_local
      end
    PHLEX

    assert_phlex_template expected, html
  end

  it "ERB no method call using <% # and %>" do
    html = %(<div><% # some_local %></div>)

    expected = <<~PHLEX.strip
      div do # some_local
      end
    PHLEX

    assert_phlex_template expected, html
  end

  it "ERB method call with long method name" do
    html = %(<div><%= some_method_super_long_method_which_should_be_split_up_and_wrapped_in_a_block %></div>)

    expected = <<~PHLEX.strip
      div do
        some_method_super_long_method_which_should_be_split_up_and_wrapped_in_a_block
      end
    PHLEX

    assert_phlex_template expected, html do
      assert_locals "some_method_super_long_method_which_should_be_split_up_and_wrapped_in_a_block"
    end
  end

  it "ERB interpolation" do
    html = %(<div><%= "\#{some_local}_text" %></div>)

    expected = <<~PHLEX.strip
      div { "\#{some_local}_text" }
    PHLEX

    assert_phlex_template expected, html do
      assert_locals "some_local"
    end
  end

  it "ERB interpolation and text node are combined to a single plain output" do
    html = %(<div><%= "\#{some_local}_text" %> More Text</div>)

    expected = <<~PHLEX.strip
      div { plain "\#{some_local}_text More Text" }
    PHLEX

    assert_phlex_template expected, html do
      assert_locals "some_local"
    end

    html = %(<div><%= [].join("-") %> \\ More "Text"</div>)

    expected = <<~PHLEX.strip
      div { plain "\#{[].join("-")} \\ More \\"Text\\"" }
    PHLEX

    assert_phlex_template expected, html
  end

  it "escapes closing parenthesis in plain output" do
    html = "<div>) <span>)</span></div>"

    expected = <<~PHLEX.strip
      div do
        plain %(\\) )
        span { %(\\)) }
      end
    PHLEX

    assert_phlex_template expected, html
  end

  it "escapes closing parenthesis in attributes" do
    html = %[<div class="px-2)"></div>]
    expected = %[div(class: %(px-2\\)))]

    assert_phlex_template expected, html
  end

  it "does not escape closing parenthesis in ERB interpolated attributes" do
    html = %q[<div class="<%= some_helper() %> px-2)">]
    expected = %q[div(class: %(#{some_helper()} px-2\\)))]

    assert_phlex_template expected, html do
      assert_helper_registrations "some_helper"
    end
  end

  it "escapes closing parenthesis in HTML comments" do
    html = %[<br /><!-- look out ) -->]
    expected = <<~PHLEX.strip
      br

      comment { %(look out \\)) }
    PHLEX

    assert_phlex_template expected, html
  end

  it "ERB loop" do
    html = <<~HTML.strip
      <% @articles.each do |article| %>
        <h1><%= article.title %></h1>
      <% end %>
    HTML

    expected = <<~PHLEX.strip
      @articles.each { |article| h1 { article.title } }
    PHLEX

    assert_phlex_template expected, html do
      assert_ivars "articles"
      assert_locals
    end
  end

  it "ERB if/else" do
    html = <<~HTML.strip
      <% if some_condition.present? %>
        <h1><%= "Some Title" %></h1>
      <% elsif another_condition == "true" %>
        <h1><%= "Alternative Title" %></h1>
      <% else %>
        <h1><%= "Default Title" %></h1>
      <% end %>
    HTML

    expected = <<~PHLEX.strip
      if some_condition.present?
        h1 { "Some Title" }
      elsif another_condition == "true"
        h1 { "Alternative Title" }
      else
        h1 { "Default Title" }
      end
    PHLEX

    assert_phlex_template expected, html do
      assert_locals "some_condition", "another_condition"
    end
  end

  it "ERB comment" do
    html = %(<div><%# The Next line has text on it %> More Text</div>)

    expected = <<~PHLEX.strip
      div do # The Next line has text on it
        plain " More Text"
      end
    PHLEX

    assert_phlex_template expected, html
  end

  it "ERB HTML safe output" do
    html = %(<div><%== "<p>Some safe HTML</p>" %></div>)

    expected = <<~PHLEX.strip
      div { unsafe_raw "<p>Some safe HTML</p>" }
    PHLEX

    assert_phlex_template expected, html
  end

  it "ERB HTML safe output with siblings" do
    html = %(<div><%== "<p>Some safe HTML</p>" %><%= some_local %><span>Text</span></div>)

    expected = <<~PHLEX.strip
      div do
        unsafe_raw "<p>Some safe HTML</p>"
        plain some_local
        span { "Text" }
      end
    PHLEX

    assert_phlex_template expected, html do
      assert_locals "some_local"
    end
  end

  it "ERB HTML safe output and other erb output" do
    html = %(<div><%== "<p>Some safe HTML</p>" %><%= "Another output" %></div>)

    expected = <<~PHLEX.strip
      div do
        unsafe_raw "<p>Some safe HTML</p>"
        plain "Another output"
      end
    PHLEX

    assert_phlex_template expected, html
  end

  it "ERB capture" do
    html = <<~HTML.strip
      <% @greeting = capture do %>
        Welcome to my shiny new web page!  The date and time is
        <%= Time.now %>
      <% end %>
    HTML

    expected = <<~PHLEX.strip
      @greeting =
        capture do
          plain " Welcome to my shiny new web page! The date and time is \#{Time.now}"
        end
    PHLEX

    assert_phlex_template expected, html do
      assert_ivars "greeting"
      assert_consts "Time"
    end
  end

  it "ERB yield" do
    html = <<~HTML.strip
      <div><%= yield %></div>
      <p><%= foo.yield %></p>
    HTML

    expected = <<~PHLEX.strip
      div { yield }

      p { foo.yield }
    PHLEX

    assert_phlex_template expected, html do
      assert_locals "foo"
    end
  end

  # rubocop:disable Lint/LiteralInInterpolation
  it "tag with text next to string erb output" do
    html = %(<div>Text<%= "ERB Text" %><%= "#{'interpolate'} text" %></div>)

    expected = <<~PHLEX.strip
    div { plain "TextERB Text#{'interpolate'} text" }
    PHLEX

    assert_phlex_template expected, html
  end
  # rubocop:enable Lint/LiteralInInterpolation
end
