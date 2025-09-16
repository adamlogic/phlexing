# frozen_string_literal: true

require_relative "../test_helper"

class Phlexing::ConverterTest < Minitest::Spec
  it "shouldn't pass render method call into the plain method" do
    html = <<~HTML.strip
      <%= render SomeView.new %>
      Hello
    HTML

    expected = <<~PHLEX.strip
      render SomeView.new
      plain "Hello"
    PHLEX

    assert_phlex_template expected, html do
      assert_consts "SomeView"
      assert_helper_registrations "render"
    end
  end

  it "should generate phlex class with component name" do
    html = %(<h1>Hello World</h1>)

    expected = <<~PHLEX.strip
      class TestComponent < Phlex::HTML
        def view_template
          h1 { "Hello World" }
        end
      end
    PHLEX

    assert_phlex expected, html, component_name: "TestComponent"
  end

  it "should generate phlex class with parent class name" do
    html = %(<h1>Hello World</h1>)

    expected = <<~PHLEX.strip
      class Component < ApplicationView
        def view_template
          h1 { "Hello World" }
        end
      end
    PHLEX

    assert_phlex expected, html, parent_component: "ApplicationView"
  end

  it "should generate phlex class with parent class name and component name" do
    html = %(<h1>Hello World</h1>)

    expected = <<~PHLEX.strip
      class TestComponent < ApplicationView
        def view_template
          h1 { "Hello World" }
        end
      end
    PHLEX

    assert_phlex expected, html, component_name: "TestComponent", parent_component: "ApplicationView"
  end

  it "should generate phlex class with yield" do
    html = %(<h1><%= yield %></h1>)

    expected = <<~PHLEX.strip
      class Component < Phlex::HTML
        def view_template
          h1 { yield }
        end
      end
    PHLEX

    assert_phlex expected, html

    html = %(<h1><%= yield if foo? %></h1>)

    expected = <<~PHLEX.strip
      class Component < Phlex::HTML
        register_value_helper :foo?

        def view_template
          h1 { yield if foo? }
        end
      end
    PHLEX

    assert_phlex expected, html do
      assert_helper_registrations "foo?"
    end
  end

  it "should generate phlex class with ivars" do
    html = %(<h1><%= @firstname %> <%= @lastname %></h1>)

    expected = <<~PHLEX.strip
      class Component < Phlex::HTML
        def initialize(firstname:, lastname:)
          @firstname = firstname
          @lastname = lastname
        end

        def view_template
          h1 do
            plain @firstname
            whitespace
            plain @lastname
          end
        end
      end
    PHLEX

    assert_phlex expected, html do
      assert_ivars "firstname", "lastname"
    end
  end

  it "should generate phlex class with ivars and block method calls" do
    html = <<~HTML.strip
      <div>
        <%= @card.title do %>
          Hey!
          <%= @card.description %>
        <% end %>
      </div>
    HTML

    expected = <<~PHLEX.strip
      class Component < Phlex::HTML
        def initialize(card:)
          @card = card
        end

        def view_template
          div do
            whitespace
            @card.title do
              plain " Hey! \#{@card.description}"
              whitespace
            end
          end
        end
      end
    PHLEX

    assert_phlex expected, html do
      assert_ivars "card"
    end
  end

  it "should generate phlex class with ivars, locals and ifs" do
    html = <<~HTML.strip
      <%= @user.name %>

      <% if show_company && @company %>
        <%= @company.name %>
      <% end %>

      <%= some_local %>
    HTML

    expected = <<~PHLEX.strip
      class Component < Phlex::HTML
        attr_accessor :show_company, :some_local

        def initialize(company:, show_company:, some_local:, user:)
          @company = company
          @show_company = show_company
          @some_local = some_local
          @user = user
        end

        def view_template
          plain @user.name

          if show_company && @company
            whitespace
            plain @company.name
          end

          plain some_local
        end
      end
    PHLEX

    assert_phlex expected, html do
      assert_ivars "company", "user"
      assert_locals "show_company", "some_local"
    end
  end

  it "should detect ivars in ERB interpolated HTML attribute" do
    html = %(<div class="<%= @classes %>"></div>)

    expected = <<~PHLEX.strip
      class Component < Phlex::HTML
        def initialize(classes:)
          @classes = classes
        end

        def view_template
          div(class: @classes)
        end
      end
    PHLEX

    assert_phlex expected, html do
      assert_ivars "classes"
    end
  end

  it "should detect locals in ERB interpolated HTML attribute" do
    html = %(<div class="<%= classes %>"></div>)

    expected = <<~PHLEX.strip
      class Component < Phlex::HTML
        attr_accessor :classes

        def initialize(classes:)
          @classes = classes
        end

        def view_template
          div(class: classes)
        end
      end
    PHLEX

    assert_phlex expected, html do
      assert_locals "classes"
    end
  end

  it "should detect method call in ERB interpolated HTML attribute" do
    html = %(<div class="<%= some_helper(with: :args) %>"></div>)

    expected = <<~PHLEX.strip
      class Component < Phlex::HTML
        register_value_helper :some_helper

        def view_template
          div(class: (some_helper(with: :args)))
        end
      end
    PHLEX

    assert_phlex expected, html do
      assert_helper_registrations "some_helper"
    end
  end

  it "should register custom helper methods" do
    html = %(<% if should_show? %><%= pretty_print(@user) %><%= another_helper(1) %><% end %>)

    expected = <<~PHLEX.strip
      class Component < Phlex::HTML
        register_output_helper :another_helper
        register_output_helper :pretty_print
        register_value_helper :should_show?

        def initialize(user:)
          @user = user
        end

        def view_template
          if should_show?
            pretty_print(@user)
            another_helper(1)
          end
        end
      end
    PHLEX

    assert_phlex expected, html do
      assert_ivars "user"
      assert_helper_registrations "another_helper", "pretty_print", "should_show?"
    end
  end

  it "should method call on object in ERB interpolated HTML attribute" do
    html = %(<div class="<%= Router.user_path(user) %>"></div>)

    expected = <<~PHLEX.strip
      class Component < Phlex::HTML
        include Phlex::Rails::Helpers::Routes

        attr_accessor :user

        def initialize(user:)
          @user = user
        end

        def view_template
          div(class: Router.user_path(user))
        end
      end
    PHLEX

    assert_phlex expected, html do
      assert_consts "Router"
      assert_locals "user"
      assert_analyzer_includes "Phlex::Rails::Helpers::Routes"
    end
  end
end
