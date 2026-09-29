#
## EPITECH PROJECT, 2026
## auth_components_test.exs
## File description:
## ExUnit for the liquid glass auth components
#

defmodule DashboardWeb.AuthComponentsTest do
  use ExUnit.Case, async: true

  import Phoenix.Component
  import Phoenix.LiveViewTest
  import DashboardWeb.AuthComponents

  alias Dashboard.Accounts.User

  describe "auth_card/1" do
    test "renders title, subtitle, content and footer" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.auth_card title="Log in" subtitle="Dashboard Sport">
          <p>inner content</p>
          <:footer>footer content</:footer>
        </.auth_card>
        """)

      assert html =~ "glass-card"
      assert html =~ "Log in"
      assert html =~ "Dashboard Sport"
      assert html =~ "inner content"
      assert html =~ "footer content"
    end

    test "omits the subtitle and the footer when not given" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.auth_card title="Create your account">
          <p>inner content</p>
        </.auth_card>
        """)

      assert html =~ "Create your account"
      refute html =~ "glass-muted font-medium"
      refute html =~ "text-center text-sm"
    end
  end

  describe "auth_input/1" do
    test "renders the label, the field name and the current value" do
      assigns = %{form: to_form(%{"email" => "kyle@example.com"}, as: "user")}

      html =
        rendered_to_string(~H"""
        <.auth_input field={@form[:email]} type="email" label="Email" autocomplete="email" />
        """)

      assert html =~ ~s(for="user_email")
      assert html =~ "Email"
      assert html =~ ~s(name="user[email]")
      assert html =~ ~s(value="kyle@example.com")
      assert html =~ ~s(autocomplete="email")
      assert html =~ "glass-input"
    end

    test "shows the hint when there is no error" do
      assigns = %{form: to_form(%{"password" => ""}, as: "user")}

      html =
        rendered_to_string(~H"""
        <.auth_input
          field={@form[:password]}
          type="password"
          label="Password"
          hint="8 characters minimum"
        />
        """)

      assert html =~ "8 characters minimum"
    end

    test "shows the errors instead of the hint and never echoes a password" do
      changeset =
        %User{}
        |> User.registration_changeset(%{
          "email" => "not-an-email",
          "password" => "supersecret123"
        })
        |> Map.put(:action, :insert)

      assigns = %{form: to_form(changeset)}

      html =
        rendered_to_string(~H"""
        <.auth_input field={@form[:email]} type="email" label="Email" hint="a helpful hint" />
        <.auth_input field={@form[:password]} type="password" label="Password" />
        """)

      assert html =~ "must have the @ sign and no spaces"
      assert html =~ ~s(aria-invalid="true")
      refute html =~ "a helpful hint"
      refute html =~ "supersecret123"
    end
  end

  describe "auth_divider/1" do
    test "renders its label inside a separator" do
      assigns = %{}

      html = rendered_to_string(~H"<.auth_divider>or</.auth_divider>")

      assert html =~ ~s(role="separator")
      assert html =~ "or"
    end
  end

  describe "oauth_button/1" do
    test "links to the provider's auth route with its label and the GitHub icon" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.oauth_button provider="github" label="Continue with GitHub" />
        """)

      assert html =~ ~s(href="/auth/github")
      assert html =~ "Continue with GitHub"
      assert html =~ "<svg"
    end

    test "falls back to a generic icon for an unknown provider" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.oauth_button provider="gitlab" label="Continue with GitLab" />
        """)

      assert html =~ ~s(href="/auth/gitlab")
      assert html =~ "hero-arrow-right-circle"
      refute html =~ "<svg"
    end
  end
end
