defmodule MentionScoreWeb.ContactUsLive.Index do
  use MentionScoreWeb, :live_view

  # In your LiveView module
  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       contact_form: %{},
       contact_errors: %{},
       sending_message: false,
       message_sent_success: false,
       message_send_error: nil
     )}
  end

  @impl true
  def handle_event("send_message", _params, socket) do
    # Handle form submission logic here
    # Validate, send email, etc.

    {:noreply, socket}
  end
end
