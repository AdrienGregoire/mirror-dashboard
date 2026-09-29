#
## EPITECH PROJECT, 2026
## auth_components.ex
## File description:
## Reusable liquid glass components shared by the auth screens
#

defmodule DashboardWeb.AuthComponents do
  use Phoenix.Component
  import DashboardWeb.CoreComponents, only: [icon: 1, translate_error: 1]

  attr :title, :string, required: true
  attr :subtitle, :string, default: nil
  slot :inner_block, required: true
  slot :footer

  def auth_card(assigns) do
    ~H"""
    <div class="glass-card p-10 sm:p-12 space-y-8">
      <div class="text-center space-y-2">
        <h1 class="glass-title text-4xl">{@title}</h1>
        <p :if={@subtitle} class="glass-muted font-medium text-base">{@subtitle}</p>
      </div>

      {render_slot(@inner_block)}

      <p :if={@footer != []} class="glass-muted text-center text-sm">
        {render_slot(@footer)}
      </p>
    </div>
    """
  end

  attr :field, Phoenix.HTML.FormField, required: true
  attr :label, :string, required: true
  attr :type, :string, default: "text"
  attr :hint, :string, default: nil, doc: "helper text, hidden while the field has errors"
  attr :rest, :global,
    include: ~w(autocomplete autofocus placeholder required minlength maxlength)

  def auth_input(%{field: field} = assigns) do
    errors =
      if Phoenix.Component.used_input?(field),
        do: Enum.map(field.errors, &translate_error/1),
        else: []

    assigns =
      assigns
      |> assign(:id, field.id)
      |> assign(:name, field.name)
      |> assign(:value, Phoenix.HTML.Form.normalize_value(assigns.type, field.value))
      |> assign(:errors, errors)

    ~H"""
    <div class="space-y-2 text-left">
      <label for={@id} class="glass-muted block text-sm font-medium">{@label}</label>
      <input
        type={@type}
        id={@id}
        name={@name}
        value={@value}
        class={["glass-input", @errors != [] && "ring-2 ring-error/60"]}
        aria-invalid={@errors != [] && "true"}
        {@rest}
      />
      <p :if={@hint && @errors == []} class="glass-muted text-xs">{@hint}</p>
      <p :for={msg <- @errors} class="flex items-center gap-2 text-sm text-error">
        <.icon name="hero-exclamation-circle" class="size-5 shrink-0" />
        {msg}
      </p>
    </div>
    """
  end

  slot :inner_block, required: true

  def auth_divider(assigns) do
    ~H"""
    <div class="flex items-center gap-4" role="separator">
      <div class="h-px flex-1 bg-(color:--glass-border-strong)"></div>
      <span class="glass-muted text-xs uppercase tracking-wider">{render_slot(@inner_block)}</span>
      <div class="h-px flex-1 bg-(color:--glass-border-strong)"></div>
    </div>
    """
  end

  attr :provider, :string, required: true
  attr :label, :string, required: true

  def oauth_button(assigns) do
    ~H"""
    <.link href={"/auth/#{@provider}"} class="glass-button w-full text-lg font-semibold gap-3">
      <.provider_icon provider={@provider} />
      {@label}
    </.link>
    """
  end

  attr :provider, :string, required: true

  defp provider_icon(%{provider: "github"} = assigns) do
    ~H"""
    <svg viewBox="0 0 16 16" fill="currentColor" class="size-5" aria-hidden="true">
      <path d="M8 0C3.58 0 0 3.58 0 8c0 3.54 2.29 6.53 5.47 7.59.4.07.55-.17.55-.38 0-.19-.01-.82-.01-1.49-2.01.37-2.53-.49-2.69-.94-.09-.23-.48-.94-.82-1.13-.28-.15-.68-.52-.01-.53.63-.01 1.08.58 1.23.82.72 1.21 1.87.87 2.33.66.07-.52.28-.87.51-1.07-1.78-.2-3.64-.89-3.64-3.95 0-.87.31-1.59.82-2.15-.08-.2-.36-1.02.08-2.12 0 0 .67-.21 2.2.82.64-.18 1.32-.27 2-.27.68 0 1.36.09 2 .27 1.53-1.04 2.2-.82 2.2-.82.44 1.1.16 1.92.08 2.12.51.56.82 1.27.82 2.15 0 3.07-1.87 3.75-3.65 3.95.29.25.54.73.54 1.48 0 1.07-.01 1.93-.01 2.2 0 .21.15.46.55.38A8.013 8.013 0 0016 8c0-4.42-3.58-8-8-8z" />
    </svg>
    """
  end

  defp provider_icon(assigns) do
    ~H"""
    <.icon name="hero-arrow-right-circle" class="size-5" />
    """
  end
end
