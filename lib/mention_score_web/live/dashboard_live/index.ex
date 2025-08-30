defmodule MentionScoreWeb.DashboardLive.Index do
  use MentionScoreWeb, :live_view

  alias MentionScore.Openrouter
  alias MentionScore.Users
  alias MentionScore.Messages

  # Model weights for final score calculation
  @model_weights %{
    # Currently only using Perplexity, set to 100%
    "perplexity" => 1.0
    # Future models can be added here:
    # "gpt-4o" => 0.30,
    # "perplexity" => 0.30,
    # "claude" => 0.15,
    # "gemini" => 0.15,
    # "deepseek" => 0.10
  }

  # Scoring system
  @scoring %{
    mentioned_and_linked: 30,
    mentioned_only: 20,
    competitor_only: 10,
    no_mention: 0
  }

  @impl true
  def mount(_params, _session, socket) do
    form = to_form(%{"domain" => ""})

    dummy_users = [
      %{
        id: 1,
        name: "John Doe",
        email: "john.doe@example.com",
        credits: 150,
        total_credits_used: 45,
        created_at: "2024-01-15"
      },
      %{
        id: 2,
        name: "Sarah Johnson",
        email: "sarah.johnson@example.com",
        credits: 75,
        total_credits_used: 125,
        created_at: "2024-02-20"
      },
      %{
        id: 3,
        name: "Michael Chen",
        email: "michael.chen@example.com",
        credits: 0,
        total_credits_used: 200,
        created_at: "2024-01-10"
      },
      %{
        id: 4,
        name: "Emily Davis",
        email: "emily.davis@example.com",
        credits: 300,
        total_credits_used: 50,
        created_at: "2024-03-05"
      },
      %{
        id: 5,
        name: "David Wilson",
        email: "david.wilson@example.com",
        credits: 25,
        total_credits_used: 175,
        created_at: "2024-02-28"
      },
      %{
        id: 6,
        name: "Lisa Anderson",
        email: "lisa.anderson@example.com",
        credits: 120,
        total_credits_used: 80,
        created_at: "2024-03-12"
      }
    ]

    products =
      case MentionScore.Gumroad.get_products() do
        {:ok, %{"products" => products}} -> products
        _ -> []
      end

    plans =
      Enum.filter(products, fn product ->
        product["name"] in ["Starter", "Growth", "Agency"]
      end)
      |> Enum.sort_by(& &1["price"], :asc)

    {:ok,
     assign(socket,
       active_tab: "score",
       show_profile_dropdown: false,
       search_domain: "",
       show_results: false,
       competitors: ["a", "b", "c"],
       insights: [
         "Optimize your meta descriptions for better click-through rates",
         "Improve page loading speed by compressing images",
         "Add structured data markup to enhance search visibility",
         "Create more location-specific content pages",
         "Build high-quality backlinks from relevant industry sites"
       ],
       current_score: 87,
       user: %{
         name: "John Doe",
         email: "john@example.com",
         credits: 150
       },
       usage_stats: %{
         geo_checks: 25,
         competitor_analysis: 12,
         reports: 8
       },
       recent_activity: [
         %{action: "GEO Score Check", domain: "example.com", date: "2 hours ago", cost: 1},
         %{action: "Competitor Analysis", domain: "mysite.com", date: "1 day ago", cost: 3},
         %{action: "GEO Score Check", domain: "testsite.org", date: "2 days ago", cost: 1},
         %{action: "Report Generated", domain: "business.net", date: "3 days ago", cost: 2}
       ],
       password_form: %{},
       password_errors: %{},
       current_user: socket.assigns.current_user,
       password_update_success: false,
       password_update_error: nil,
       chat_messages: [],
       current_message: "",
       ai_typing: false,
       users: Users.list_users(),
       total_users: Users.count_users(),
       active_users: Users.count_active_users(),
       inactive_users: Users.count_inactive_users(),
       zero_credit_users: Users.count_users_with_zero_credits(),
       messages: Messages.list_messages_by_user_id(socket.assigns.current_user.id),
       admin_email: System.get_env("ADMIN_EMAIL"),
       filtered_users: dummy_users,
       user_search: "",
       current_filter: "all",
       show_filter_dropdown: false,
       show_delete_modal: false,
       delete_user_id: nil,
       delete_user_name: nil,
       form: form,
       loading: false,
       plans: plans,
       chat_session_id: generate_chat_session_id()
     )}
  end

  @impl true
  def handle_event("change_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, active_tab: tab, show_profile_dropdown: false)}
  end

  @impl true
  def handle_event("toggle_profile_dropdown", _params, socket) do
    {:noreply, assign(socket, show_profile_dropdown: !socket.assigns.show_profile_dropdown)}
  end

  @impl true
  def handle_event("close_profile_dropdown", _params, socket) do
    {:noreply, assign(socket, show_profile_dropdown: false)}
  end

  @impl true
  def handle_event("update_search", %{"domain" => domain}, socket) do
    {:noreply, assign(socket, search_domain: domain)}
  end

  @impl true
  def handle_event("analyze_domain", params, socket) do
    if socket.assigns.current_user.credits == 0 do
      {:noreply,
       socket
       |> put_flash(:error, "Not enough credits to proceed. Please buy credits.")}
    else
      questions =
        Openrouter.get_domain_related_questions(params["domain"])
        |> extract_questions()
        |> case do
          {:ok, extracted_questions} -> extracted_questions
          {:error, :invalid_format} -> []
        end

      socket =
        socket
        |> assign(:loading, true)
        |> assign(:show_results, false)

      task =
        Task.async(fn ->
          try do
            calculate_geo_score(params["domain"], questions)
          rescue
            e ->
              {:error, "Calculation failed: #{Exception.message(e)}"}
          catch
            :exit, reason ->
              {:error, "Process exited: #{inspect(reason)}"}
          end
        end)

      socket = assign(socket, :calculation_task, task)

      {:noreply, socket}
    end
  end

  ########################## admin functions ##################

  @impl true
  def handle_event("search_users", %{"search" => search_term}, socket) do
    downcased_term = String.downcase(search_term)
    users = Users.list_users()

    filtered_users =
      Enum.filter(users, fn user ->
        user.first_name
        |> String.downcase()
        |> String.contains?(downcased_term) or
          user.last_name
          |> String.downcase()
          |> String.contains?(downcased_term)
      end)

    # filtered_users = filter_users_by_search(socket.assigns.users, search_term)

    # socket =
    #   socket
    #   |> assign(:user_search, search_term)
    #   |> assign(:filtered_users, filtered_users)

    {:noreply,
     socket
     |> assign(users: filtered_users)}
  end

  def handle_event("toggle_filter_dropdown", _params, socket) do
    {:noreply, assign(socket, :show_filter_dropdown, !socket.assigns.show_filter_dropdown)}
  end

  def handle_event("filter_users", %{"filter" => filter}, socket) do
    filtered_users = apply_user_filter(socket.assigns.users, filter)

    socket =
      socket
      |> assign(:current_filter, filter)
      |> assign(:filtered_users, filtered_users)
      |> assign(:show_filter_dropdown, false)

    {:noreply, socket}
  end

  def handle_event(
        "confirm_delete_user",
        %{"user-id" => user_id, "user-name" => user_name},
        socket
      ) do
    socket =
      socket
      |> assign(:show_delete_modal, true)
      |> assign(:delete_user_id, String.to_integer(user_id))
      |> assign(:delete_user_name, user_name)

    {:noreply, socket}
  end

  def handle_event("cancel_delete_user", _params, socket) do
    socket =
      socket
      |> assign(:show_delete_modal, false)
      |> assign(:delete_user_id, nil)
      |> assign(:delete_user_name, nil)

    {:noreply, socket}
  end

  def handle_event("delete_user", %{"user-id" => user_id}, socket) do
    user_id = String.to_integer(user_id)
    updated_users = Enum.reject(socket.assigns.users, fn user -> user.id == user_id end)

    filtered_users =
      apply_current_filters(
        updated_users,
        socket.assigns.user_search,
        socket.assigns.current_filter
      )

    socket =
      socket
      |> assign(:users, updated_users)
      |> assign(:filtered_users, filtered_users)
      |> assign(:show_delete_modal, false)
      |> assign(:delete_user_id, nil)
      |> assign(:delete_user_name, nil)
      |> put_flash(:info, "User deleted successfully")

    {:noreply, socket}
  end

  def handle_event("view_user_details", %{"user-id" => user_id}, socket) do
    # You can implement a detailed view modal or redirect to a detail page
    {:noreply, put_flash(socket, :info, "View user details for ID: #{user_id}")}
  end

  def handle_event("edit_user_credits", %{"user-id" => user_id}, socket) do
    # You can implement a modal to edit user credits
    {:noreply, put_flash(socket, :info, "Edit credits for user ID: #{user_id}")}
  end

  # Handle password update form submission
  def handle_event("update_password", params, socket) do
    attrs = %{"password" => params["password"], "confirm_password" => params["confirm_password"]}

    if params["password"] == params["confirm_password"] do
      case Users.update_user_password(
             socket.assigns.current_user,
             params["current_password"],
             attrs
           ) do
        {:ok, _user} ->
          {:noreply,
           socket
           |> put_flash(:info, "Password updated successfully")}

        {:error, reason} ->
          format_changeset__error(reason)

          {:noreply,
           socket
           |> put_flash(:error, format_changeset__error(reason))}
      end
    else
      {:noreply,
       socket
       |> put_flash(:error, "Passsword mismatch. Confirm your password again")}
    end
  end

  @impl true
  def handle_event("logout", _params, socket) do
    # Implement logout logic here
    {:noreply, socket}
  end

  ####################### chat functions ################
  def handle_event("send_message", %{"message" => message}, socket) do
    if socket.assigns.current_user.credits == 0 do
      {:noreply,
       socket
       |> put_flash(:error, "Not enough credits to proceed. Please buy credits.")}
    else
      case Messages.create_message(%{
             "content" => message,
             "message_by" => "user",
             "user_id" => socket.assigns.current_user.id
           }) do
        {:ok, message} ->
          Task.start(fn ->
            get_response(message.content, socket)
          end)

          {:noreply,
           socket
           |> assign(:messages, Messages.list_messages_by_user_id(socket.assigns.current_user.id))
           |> assign(:ai_typing, true)}

        {:error, _reason} ->
          {:noreply,
           socket
           |> put_flash(:error, "please try again")}
      end
    end
  end

  def handle_event("update_message", %{"message" => message}, socket) do
    {:noreply, assign(socket, :current_message, message)}
  end

  def handle_event("start_new_chat", _params, socket) do
    case Messages.delete_all_messages_by_user_id(socket.assigns.current_user.id) do
      {_count, _} ->
        {:noreply,
         socket
         |> assign(messages: Messages.list_messages_by_user_id(socket.assigns.current_user.id))}

      _ ->
        {:noreply,
         socket
         |> put_flash(:error, "Unable to start new chat. Try Again")}
    end
  end

  def handle_event("send_quick_question", %{"question" => question}, socket) do
    handle_event("send_message", %{"message" => question}, socket)
  end

  @impl true
  def handle_info({ref, result}, socket) when socket.assigns.calculation_task.ref == ref do
    # Clean up the task
    competitors =
      Openrouter.get_competitors(socket.assigns.search_domain)
      |> extract_competitors()

    final_score =
      case result do
        {:ok, result} -> result.final_score
        _ -> ""
      end

    improvement_suggestions =
      Openrouter.get_improvement_tips(socket.assigns.search_domain, competitors, final_score)
      |> extract_improvement_suggestions()

    Process.demonitor(ref, [:flush])

    case result do
      {:ok, result} ->
        case Users.deduct_user_credit(socket.assigns.current_user.id) do
          {:ok, _user} ->
            Users.add_total_credit_count(socket.assigns.current_user.id)

            {:noreply,
             socket
             |> assign(:loading, false)
             |> assign(:calculation_task, nil)
             |> assign(:show_results, true)
             |> assign(:current_score, result.final_score)
             |> assign(:insights, improvement_suggestions)
             |> assign(:competitors, competitors)
             |> assign(:score_breakdown, result.score_breakdown)
             |> assign(:improvement_suggestions, improvement_suggestions)
             |> assign(:current_user, Users.get_user(socket.assigns.current_user.id))}

          {:error, _reason} ->
            {:noreply,
             socket
             |> put_flash(:error, "Something went wrong. Please try again.")}
        end

      {:error, reason} ->
        IO.puts("Error: #{reason}")

        {:noreply,
         socket
         |> assign(:loading, false)
         |> assign(:calculation_task, nil)
         |> assign(:error, reason)}
    end
  end

  # Handle task monitoring (in case task crashes)
  @impl true
  def handle_info({:DOWN, ref, :process, _pid, reason}, socket)
      when socket.assigns.calculation_task.ref == ref do
    {:noreply,
     socket
     |> assign(:loading, false)
     |> assign(:calculation_task, nil)
     |> assign(:error, "Calculation process crashed: #{inspect(reason)}")}
  end

  @impl true
  def handle_info({:response_received, status}, socket) do
    case status do
      :success ->
        case Users.deduct_user_credit(socket.assigns.current_user.id) do
          {:ok, _user} ->
            Users.add_total_credit_count(socket.assigns.current_user.id)

            {:noreply,
             socket
             |> assign(:ai_typing, false)
             |> assign(:current_user, Users.get_user(socket.assigns.current_user.id))
             |> assign(
               :messages,
               Messages.list_messages_by_user_id(socket.assigns.current_user.id)
             )}

          {:error, _reason} ->
            {:noreply,
             socket
             |> put_flash(:error, "Something went wrong. Please try again.")}
        end

      _ ->
        {:noreply,
         socket
         |> assign(:ai_typing, false)
         |> put_flash(:error, "please try again")}
    end
  end

  def handle_info({:simulate_ai_response, user_message}, socket) do
    # Simulate AI response - replace with actual AI API integration
    ai_response = generate_ai_response(user_message)

    ai_message = %{
      type: "assistant",
      content: ai_response,
      timestamp: format_timestamp(DateTime.utc_now()),
      id: generate_message_id()
    }

    updated_messages = socket.assigns.chat_messages ++ [ai_message]

    socket =
      socket
      |> assign(:chat_messages, updated_messages)
      |> assign(:ai_typing, false)
      |> update(:user, fn user -> %{user | credits: user.credits - 1} end)

    {:noreply, socket}
  end

  def extract_questions({:ok, response}) do
    with content when is_binary(content) <-
           get_in(response, ["choices", Access.at(0), "message", "content"]),
         {:ok, parsed_json} <- extract_json_from_markdown(content),
         questions when is_list(questions) <- Map.get(parsed_json, "generated_questions") do
      {:ok, questions}
    else
      _ -> {:error, :invalid_format}
    end
  end

  def extract_questions({:error, _reason}) do
    {:error, :invalid_format}
  end

  def score_color_class(score) when is_integer(score) do
    cond do
      score < 30 -> "text-3xl font-bold text-red-500"
      score < 70 -> "text-3xl font-bold text-orange-500"
      score >= 80 -> "text-3xl font-bold text-green-500"
      true -> "text-3xl font-bold text-gray-500"
    end
  end

  def rank_color_class(score) when is_integer(score) do
    cond do
      score < 30 -> "font-semibold text-red-500"
      score < 70 -> "font-semibold text-orange-500"
      score >= 80 -> "font-semibold text-green-500"
      true -> "font-semibold text-gray-500"
    end
  end

  def geo_optimization(score) when is_integer(score) do
    cond do
      score < 30 -> "Low"
      score < 70 -> "Moderate"
      score >= 80 -> "Excellent"
      true -> "No"
    end
  end

  def geo_avg(score) when is_integer(score) do
    cond do
      score == 0 -> "Nowhere"
      score < 30 -> "Very Low"
      score < 70 -> "Moderately"
      score >= 80 -> "Pretty Well"
      true -> "No"
    end
  end

  def extract_competitors({:ok, response}) do
    with content when is_binary(content) <-
           get_in(response, ["choices", Access.at(0), "message", "content"]),
         {:ok, parsed_json} <- extract_json_from_markdown(content),
         competitors when is_list(competitors) <- Map.get(parsed_json, "competitors") do
      competitors
    else
      _ -> []
    end
  end

  def extract_competitors({:error, _response}) do
    []
  end

  def extract_improvement_suggestions({:ok, response}) do
    with content when is_binary(content) <-
           get_in(response, ["choices", Access.at(0), "message", "content"]),
         {:ok, parsed_json} <- extract_json_from_markdown(content),
         true <- is_list(parsed_json) do
      parsed_json
    else
      _ -> []
    end
  end

  def extract_improvement_suggestions({:error, _response}), do: []

  def extract_domains(urls) when is_list(urls) do
    urls
    |> Enum.map(&get_domain/1)
    |> Enum.uniq()
    |> Enum.sort()
  end

  defp get_domain(url) do
    uri = URI.parse(url)

    # URI.parse may return nil for host if input is malformed
    uri.host
    # remove "www."
    |> String.replace_leading("www.", "")
  end

  # This function extracts the JSON part from the markdown string and decodes it
  defp extract_json_from_markdown(content) do
    content
    |> String.replace_prefix("```json\n", "")
    |> String.replace_suffix("\n```", "")
    |> Jason.decode()
  end

  def format_changeset__error(%Ecto.Changeset{errors: errors}) when is_list(errors) do
    case errors do
      [] ->
        "Unknown error"

      [{_field, {message, _opts}} | _rest] ->
        case message do
          "is not valid" -> "Current password is not valid"
          message -> message
        end
    end
  end

  def format_first_error(_), do: "Unknown error"
  # end

  # Helper function to validate password update
  # defp validate_password_update(current_password, new_password, confirm_password, user) do
  #   errors = %{}

  #   # Validate current password
  #   errors = if current_password == "" do
  #     Map.put(errors, :current_password, "Current password is required")
  #   else
  #     # You'll need to implement password verification logic here
  #     # This depends on how you're storing/hashing passwords
  #     if verify_current_password(user, current_password) do
  #       errors
  #     else
  #       Map.put(errors, :current_password, "Current password is incorrect")
  #     end
  #   end

  #   # Validate new password
  #   errors = cond do
  #     new_password == "" ->
  #       Map.put(errors, :new_password, "New password is required")

  #     String.length(new_password) < 8 ->
  #       Map.put(errors, :new_password, "Password must be at least 8 characters long")

  #     !Regex.match?(~r/^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)/, new_password) ->
  #       Map.put(errors, :new_password, "Password must contain uppercase, lowercase, and numeric characters")

  #     true ->
  #       errors
  #   end

  #   # Validate password confirmation
  #   errors = cond do
  #     confirm_password == "" ->
  #       Map.put(errors, :confirm_password, "Password confirmation is required")

  #     new_password != confirm_password ->
  #       Map.put(errors, :confirm_password, "Passwords do not match")

  #     true ->
  #       errors
  #   end

  #   errors
  # end

  # Helper function to verify current password
  # defp verify_current_password(user, password) do
  # This depends on your authentication system
  # If using bcrypt:
  # Bcrypt.verify_pass(password, user.password_hash)

  # If using pbkdf2:
  # Pbkdf2.verify_pass(password, user.password_hash)

  # If using argon2:
  # Argon2.verify_pass(password, user.password_hash)

  # Replace this with your actual password verification logic
  # true # Placeholder - implement according to your auth system
  # end

  # Helper function to update user password
  # defp update_user_password(user, current_password, new_password) do
  # This should update the user's password in your database
  # Example implementation:

  # changeset = user
  # |> Ecto.Changeset.cast(%{password: new_password}, [:password])
  # |> validate_required([:password])
  # |> put_password_hash()  # Your password hashing function

  # Repo.update(changeset)

  # Placeholder - implement according to your user schema and repo
  #   {:ok, user}
  # end

  # Helper function to format date
  # defp format_date(date) do
  #   case date do
  #     %DateTime{} = dt ->
  #       dt
  #       |> DateTime.to_date()
  #       |> Date.to_string()
  #       |> format_date_string()

  #     %NaiveDateTime{} = ndt ->
  #       ndt
  #       |> NaiveDateTime.to_date()
  #       |> Date.to_string()
  #       |> format_date_string()

  #     %Date{} = d ->
  #       d
  #       |> Date.to_string()
  #       |> format_date_string()

  #     _ ->
  #       "Not available"
  #   end
  # end

  # defp format_date_string(date_string) do
  #   case Date.from_iso8601(date_string) do
  #     {:ok, date} ->
  #       date
  #       |> Calendar.strftime("%B %d, %Y")

  #     _ ->
  #       "Not available"
  #   end
  # end

  # Helper functions for rendering
  defp tab_class(current_tab, tab_name) do
    base_class =
      "w-full flex items-center space-x-3 px-4 py-3 rounded-xl transition-all duration-200"

    if current_tab == tab_name do
      base_class <> " bg-gray-200/50 border-2 border-solid text-black"
    else
      base_class <> " text-black hover:bg-gray-200/50"
    end
  end

  defp score_circle_offset(score) do
    circumference = 2 * :math.pi() * 56
    circumference * (1 - score / 100)
  end

  # Green
  defp score_color(score) when score >= 80, do: "#22c55e"
  # Orange
  defp score_color(score) when score >= 40, do: "#f97316"
  # Red
  defp score_color(_score), do: "#ef4444"

  def get_response(message, socket) do
    prompt = generate_prompt(message, socket.assigns.current_user.id)

    case MentionScore.Openrouter.chat_with_geora(prompt) do
      {:ok, response} ->
        content =
          response["choices"]
          |> List.first()
          |> Map.get("message")
          |> Map.get("content")
          |> clean_content()

        # formatted_content =
        #   case MentionScore.Openrouter.clean_geora_response(content) do
        #     {:ok, formatted_response} -> formatted_response["choices"] |> List.first() |> Map.get("message") |> Map.get("content")
        #     {:error, _reason} -> content
        #   end

        case Messages.create_message(%{
               "content" => content,
               "message_by" => "ai",
               "user_id" => socket.assigns.current_user.id
             }) do
          {:ok, _message} ->
            send(socket.root_pid, {:response_received, :success})

          {:error, _reason} ->
            send(socket.root_pid, {:response_received, :error})
        end

      _ ->
        send(socket.root_pid, {:response_received, :error})
    end
  end

  def generate_prompt(message, user_id) do
    messages = Messages.list_messages_by_user_id(user_id)

    # Format messages as conversation history
    conversation_history =
      messages
      |> Enum.map(fn msg -> "#{msg.message_by}: #{msg.content}" end)
      |> Enum.join("\n")

    # Construct the final prompt including the conversation history
    """
    You are Geora, a powerful AI assistant specialized in GEO (Generative Engine
    Optimization) — the science of improving visibility, mentions, and citations in
    AI-generated responses (e.g., ChatGPT, Claude, Gemini, Perplexity, AI Overviews).
    You also support advanced tasks at the intersection of GEO, SEO, content strategy,
    competitive analysis, and AI assistant behavior.
    YOUR CORE PURPOSE
    Help users:
    ● Understand why they (or competitors) show up — or don’t — in AI search
    results
    ● Improve their website or content to be cited more often by AI tools
    ● Analyze AI visibility across multiple models (using browsing)
    ● Create content that ranks in both traditional search and AI-generated results
    ● Benchmark competitors and reverse-engineer their visibility
    ● Suggest content types, structures, schema, and queries to outrank others
    ● Track and improve GEO performance over time
    ● Bridge classic SEO best practices with AI search-specific needs
    INTELLIGENT SCOPE HANDLING
    You do not limit yourself to GEO-only vocabulary. Instead, you intelligently identify:
    ● When a user needs SEO insights to support GEO goals
    ● When competitor or content research serves GEO strategy
    ● When citation optimization requires both on-page and off-page evaluation
    ● When browsing live data adds critical context (SERPs, answer boxes, AI
    replies)
    You never say “I can’t answer” unless it’s fully unrelated to AI search, content
    visibility, or ranking (e.g., pure dev questions, legal advice, or crypto).
    TASK TYPES YOU CAN HANDLE
    You are capable of:
    ● Scanning live web pages to understand content quality
    ● Checking which brands are being cited by ChatGPT, Perplexity, etc.
    ● Comparing two domains for their GEO/SEO strength
    ● Recommending exact search queries users should optimize for
    ● Drafting structured content outlines designed for AI visibility
    ● Scoring existing content using a GEO lens
    ● Helping users rewrite or improve pages for better AI citation
    ● Suggesting schema, metadata, or HTML improvements
    ● Mapping how users move from AI answers to landing pages
    ● Identifying gaps in the content ecosystem AI models might fill with new
    sources
    HOW YOU RESPOND
    ● Use expert, confident tone — never vague
    ● Be concise, but include details or examples when useful
    ● Prefer structure: lists, bullet points, tables, prompt examples
    ● When doing analysis, explain the why behind suggestions
    ● Use simple headers if the response is long
    ● When appropriate, suggest actions users can take right now
    ● return a clean human friendly resopnse without any bold, italics, tables, bullet points etc. Just a plain simple response.
    WHEN TO USE BROWSING
    Use browsing when:
    ● Comparing real-time mentions or rankings
    ● Evaluating content structure or metadata of live pages
    ● Fetching specific examples from ChatGPT, Perplexity, or Google AI Overviews
    ● Analyzing competitors’ content footprint
    ● Searching for tools, stats, or case studies related to the prompt
    OFF-TOPIC MANAGEMENT
    If a question has no connection to:
    ● Content visibility
    ● Search engine or AI assistant behavior
    ● AI-generated response optimization
    ● Content structure, schema, or prompt design
    ● Ranking, mentions, comparisons, competitive analysis
    Then politely reply:
    "This assistant is designed to support Generative Engine Optimization and AI-driven
    content strategy. Please rephrase your question within that focus."
    FINAL EXECUTION
    Here is the current conversation:
    #{conversation_history}
    Now respond to this user input:
    User: #{message}
    """
  end

  def clean_content(str) do
    str
    # Remove \[ (escaped properly)
    |> String.replace(~r/\\\[/, "")
    # Remove \] (escaped properly)
    |> String.replace(~r/\\\]/, "")
    # Remove \boxed{number}
    |> String.replace(~r/\\boxed{\d+}/, "")
    # Replace newlines with spaces
    |> String.replace("\n", " ")
    # Replace multiple spaces with a single space
    |> String.replace(~r/\s+/, " ")
    # Trim leading/trailing spaces
    |> String.trim()
  end

  # Helper functions:

  defp generate_chat_session_id do
    :crypto.strong_rand_bytes(16) |> Base.encode64()
  end

  defp generate_message_id do
    :crypto.strong_rand_bytes(8) |> Base.encode64()
  end

  defp format_timestamp(datetime) do
    datetime
    |> DateTime.to_time()
    |> Time.to_string()
    |> String.slice(0, 5)
  end

  defp generate_ai_response(user_message) do
    # Dummy responses - replace with actual AI API integration
    responses = [
      "Great question! To improve your GEO score, I recommend focusing on these key areas: optimizing your meta tags, improving page load speed, ensuring mobile responsiveness, and creating high-quality, location-specific content. Would you like me to elaborate on any of these points?",
      "Based on your question about #{String.slice(user_message, 0, 20)}..., here are some actionable insights: First, analyze your current performance metrics, then identify gaps compared to top competitors, and finally implement targeted improvements. I can help you dive deeper into any specific area.",
      "That's an excellent point about website optimization! The key factors that influence your GEO score include technical SEO elements, content quality, user experience metrics, and local optimization signals. Each of these contributes differently to your overall ranking potential.",
      "I'd be happy to help you with that! For effective competitor analysis, start by identifying your top 5-10 competitors, analyze their technical implementation, content strategy, and user experience. Then benchmark your performance against theirs to identify opportunities for improvement."
    ]

    Enum.random(responses)
  end

  # Helper functions for filtering

  defp filter_users_by_search(users, ""), do: users

  defp filter_users_by_search(users, search_term) do
    search_term = String.downcase(search_term)

    Enum.filter(users, fn user ->
      String.contains?(String.downcase(user.name), search_term) ||
        String.contains?(String.downcase(user.email), search_term)
    end)
  end

  defp apply_current_filters(users, search_term, filter) do
    users
    |> filter_users_by_search(search_term)
    |> apply_user_filter(filter)
  end

  defp apply_user_filter(users, "all"), do: users
  defp apply_user_filter(users, "active"), do: Enum.filter(users, fn user -> user.credits > 0 end)

  defp apply_user_filter(users, "high_credits"),
    do: Enum.filter(users, fn user -> user.credits > 100 end)

  defp apply_user_filter(users, "low_credits"),
    do: Enum.filter(users, fn user -> user.credits < 50 end)

  # defp status_badge_class(credits) when credits > 100, do: "inline-flex px-2 py-1 text-xs font-semibold rounded-full bg-green-100 text-green-800"
  # defp status_badge_class(credits) when credits > 50, do: "inline-flex px-2 py-1 text-xs font-semibold rounded-full bg-green-100 text-green-800"
  # defp status_badge_class(credits) when credits > 0, do: "inline-flex px-2 py-1 text-xs font-semibold rounded-full bg-green-100 text-green-800"
  # defp status_badge_class(credits) when credits > 100, do: "inline-flex px-2 py-1 text-xs font-semibold rounded-full bg-green-100 text-green-800"
  # defp status_badge_class(_), do: "inline-flex px-2 py-1 text-xs font-semibold rounded-full bg-green-100 text-green-800"
  # defp status_badge_class(credits) when credits > 50, do: "inline-flex px-2 py-1 text-xs font-semibold rounded-full bg-yellow-100 text-yellow-800"
  # defp status_badge_class(credits) when credits > 0, do: "inline-flex px-2 py-1 text-xs font-semibold rounded-full bg-orange-100 text-orange-800"
  # defp status_badge_class(_), do: "inline-flex px-2 py-1 text-xs font-semibold rounded-full bg-red-100 text-red-800"

  # defp user_status(credits) when credits > 100, do: "Premium"
  # defp user_status(credits) when credits > 50, do: "Active"
  # defp user_status(credits) when credits > 0, do: "Low Credits"
  # defp user_status(_), do: "Inactive"

  def fetch_homepage_html(domain) do
    url = "https://#{domain}"

    # case Finch.build(:get, url)
    #      |> Finch.request(MyAppFinch) do
    #   {:ok, %Finch.Response{status: 200, body: body}} -> {:ok, body}
    #   {:ok, %Finch.Response{status: code}} -> {:error, "HTTP #{code}"}
    #   {:error, reason} -> {:error, reason}
    # end

    case Finch.build(:get, url)
         |> Finch.request(MentionScore.Finch) do
      {:ok, %Finch.Response{status: status, body: body}} when status in 200..299 ->
        {:ok, body}

      {:ok, %Finch.Response{status: status, body: body}} when status > 299 ->
        {:error, body}

      {:ok, %Finch.Response{status: status, body: body}} ->
        {:error, status, body}

      {:error, reason} ->
        {:error, reason}

      _ ->
        :ok
    end
  end

  # ************************************************************************
  # ************************************************************************
  # ************************************************************************

  def calculate_geo_score(domain, questions) when is_binary(domain) and is_list(questions) do
    case process_questions(domain, questions) do
      {:ok, results} ->
        final_score = calculate_simple_score(results)

        result = %{
          domain: domain,
          final_score: final_score,
          total_questions: length(questions),
          model_results: results,
          score_breakdown: generate_score_breakdown(results),
          citations_summary: generate_citations_summary(results),
          improvement_suggestions: generate_improvement_suggestions(final_score, results)
        }

        {:ok, result}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp process_questions(domain, questions) do
    results =
      questions
      |> Enum.with_index(1)
      |> Enum.map(fn {question, index} ->
        case process_single_question(domain, question, index) do
          {:ok, result} ->
            result

          {:error, reason} ->
            %{
              question_index: index,
              question: question,
              status: :error,
              error: reason,
              score: 0,
              citations: [],
              domain_status: :no_mention
            }
        end
      end)

    successful_results = Enum.filter(results, fn r -> r.status != :error end)

    if length(successful_results) > 0 do
      model_results = %{
        "perplexity" => %{
          questions_processed: length(results),
          successful_questions: length(successful_results),
          question_results: results,
          total_score: Enum.sum(Enum.map(results, & &1.score)),
          average_score: calculate_average_score(results)
        }
      }

      {:ok, model_results}
    else
      {:error, "No questions could be processed successfully"}
    end
  end

  defp process_single_question(domain, question, index) do
    case Openrouter.ask_question_from_ai(question) do
      {:ok, response} ->
        case analyze_response(domain, response) do
          {:ok, analysis} ->
            result = %{
              question_index: index,
              question: question,
              status: :success,
              score: analysis.score,
              citations: analysis.citations,
              domain_status: analysis.domain_status,
              content_snippet: extract_content_snippet(response),
              analysis_details: analysis
            }

            {:ok, result}

          {:error, reason} ->
            {:error, "Failed to analyze response for question #{index}: #{reason}"}
        end

      {:error, reason} ->
        {:error, "API call failed for question #{index}: #{reason}"}
    end
  end

  defp analyze_response(domain, response) do
    try do
      citations = extract_citations(response)
      content = extract_content(response)
      clean_domain = clean_domain_for_comparison(domain)

      # Simple analysis: check if domain appears in citations or content
      {domain_status, score} = calculate_question_score(clean_domain, citations, content)

      analysis = %{
        domain_status: domain_status,
        score: score,
        citations: citations,
        clean_domain: clean_domain,
        content_length: String.length(content),
        citation_count: length(citations)
      }

      {:ok, analysis}
    rescue
      e ->
        {:error, "Analysis failed: #{Exception.message(e)}"}
    end
  end

  # defp calculate_question_score(clean_domain, citations, content) do
  #   # Check if domain appears in citations
  #   domain_in_citations = domain_appears_in_citations?(clean_domain, citations)

  #   # Check if domain appears in content
  #   domain_in_content = domain_appears_in_content?(clean_domain, content)

  #   # Simple scoring logic
  #   cond do
  #     domain_in_citations and domain_in_content ->
  #       # Best case: domain is both cited and mentioned
  #       {:cited_and_mentioned, 25}

  #     domain_in_citations ->
  #       # Good case: domain is cited
  #       {:cited_only, 20}

  #     domain_in_content ->
  #       # OK case: domain is mentioned but not cited
  #       {:mentioned_only, 10}

  #     length(citations) > 0 ->
  #       # Domain not found but there are citations (competitors might be cited)
  #       {:competitors_cited, 5}

  #     true ->
  #       # No citations and no mention
  #       {:no_mention, 0}
  #   end
  # end

  defp calculate_question_score(clean_domain, _citations, content) do
    # Only check if domain appears in content (ignore citations)
    domain_in_content = domain_appears_in_content?(clean_domain, content)

    # Simplified scoring logic - only based on content mentions
    cond do
      domain_in_content ->
        # Domain is mentioned in content
        {:mentioned, 25}

      true ->
        # Domain not mentioned
        {:no_mention, 0}
    end
  end

  # defp domain_appears_in_citations?(clean_domain, citations) do
  #   citations
  #   |> Enum.any?(fn citation ->
  #     case citation do
  #       url when is_binary(url) ->
  #         clean_citation = clean_domain_for_comparison(url)
  #         String.contains?(clean_citation, clean_domain) or
  #         String.contains?(clean_domain, clean_citation)
  #       _ ->
  #         false
  #     end
  #   end)
  # end

  defp domain_appears_in_content?(clean_domain, content) when is_binary(content) do
    content_lower = String.downcase(content)

    # Check for various patterns of domain mentions
    String.contains?(content_lower, clean_domain) or
      String.contains?(content_lower, "#{clean_domain}.com") or
      String.contains?(content_lower, "www.#{clean_domain}") or
      String.contains?(content_lower, "#{clean_domain}.net") or
      String.contains?(content_lower, "#{clean_domain}.org")
  end

  defp domain_appears_in_content?(_, _), do: false

  defp calculate_simple_score(model_results) do
    question_results = model_results["perplexity"].question_results
    successful_results = Enum.filter(question_results, fn r -> r.status == :success end)

    if length(successful_results) > 0 do
      # Calculate total score from all questions
      total_score = Enum.sum(Enum.map(successful_results, & &1.score))
      # 25 is max score per question
      max_possible_score = length(successful_results) * 25

      # Convert to percentage out of 100
      percentage_score = total_score / max_possible_score * 100

      # Round and ensure it's between 0-100
      percentage_score
      |> Float.round(1)
      |> max(0)
      |> min(100)
      |> trunc()
    else
      0
    end
  end

  defp calculate_average_score(results) do
    successful_results = Enum.filter(results, fn r -> r.status == :success end)

    if length(successful_results) > 0 do
      total_score = Enum.sum(Enum.map(successful_results, & &1.score))
      Float.round(total_score / length(successful_results), 2)
    else
      0.0
    end
  end

  # Helper functions for extracting data from API response
  defp extract_citations(response) do
    case response do
      %{"citations" => citations} when is_list(citations) ->
        citations

      %{"choices" => [%{"message" => %{"annotations" => annotations}} | _]}
      when is_list(annotations) ->
        annotations
        |> Enum.filter(fn annotation ->
          Map.get(annotation, "type") == "url_citation"
        end)
        |> Enum.map(fn annotation ->
          case Map.get(annotation, "url_citation") do
            %{"url" => url} -> url
            _ -> nil
          end
        end)
        |> Enum.filter(& &1)

      _ ->
        []
    end
  end

  defp extract_content(response) do
    case response do
      %{"choices" => [%{"message" => %{"content" => content}} | _]} when is_binary(content) ->
        content

      %{"content" => content} when is_binary(content) ->
        content

      _ ->
        ""
    end
  end

  # defp clean_domain_for_comparison(domain) do
  #   domain
  #   |> String.downcase()
  #   |> String.replace(~r/^https?:\/\//, "")
  #   |> String.replace(~r/^www\./, "")
  #   |> String.replace(~r/\/$/, "")
  #   |> String.trim()
  # end

  defp clean_domain_for_comparison(domain) do
    domain
    |> String.downcase()
    |> String.replace(~r/^https?:\/\//, "")
    |> String.replace(~r/^www\./, "")
    |> String.replace(~r/\/.*$/, "")
    |> String.split(".")
    |> get_main_part()
  end

  defp get_main_part(parts) do
    # Find logic based on length and common tlds
    cond do
      Enum.count(parts) == 2 ->
        hd(parts)

      Enum.count(parts) == 3 and Enum.at(parts, 0) != "www" ->
        Enum.at(parts, 1)

      Enum.count(parts) == 3 and Enum.at(parts, 0) == "www" ->
        Enum.at(parts, 1)

      true ->
        hd(parts)
    end
  end

  defp extract_content_snippet(response) do
    content = extract_content(response)

    if String.length(content) > 200 do
      String.slice(content, 0, 200) <> "..."
    else
      content
    end
  end

  # defp generate_score_breakdown(model_results) do
  #   question_results = model_results["perplexity"].question_results

  #   # Count occurrences of each status
  #   status_counts =
  #     question_results
  #     |> Enum.group_by(& &1.domain_status)
  #     |> Enum.map(fn {status, results} ->
  #       {status, length(results)}
  #     end)
  #     |> Enum.into(%{})

  #   successful_results = Enum.filter(question_results, fn r -> r.status == :success end)

  #   %{
  #     model: "perplexity",
  #     total_score: model_results["perplexity"].total_score,
  #     average_score: model_results["perplexity"].average_score,
  #     questions_processed: model_results["perplexity"].questions_processed,
  #     successful_questions: length(successful_results),
  #     status_breakdown: status_counts,
  #     score_details: %{
  #       cited_and_mentioned: Map.get(status_counts, :cited_and_mentioned, 0),
  #       cited_only: Map.get(status_counts, :cited_only, 0),
  #       mentioned_only: Map.get(status_counts, :mentioned_only, 0),
  #       competitors_cited: Map.get(status_counts, :competitors_cited, 0),
  #       no_mention: Map.get(status_counts, :no_mention, 0)
  #     }
  #   }
  # end

  defp generate_score_breakdown(model_results) do
    question_results = model_results["perplexity"].question_results

    # Count occurrences of each status
    status_counts =
      question_results
      |> Enum.group_by(& &1.domain_status)
      |> Enum.map(fn {status, results} ->
        {status, length(results)}
      end)
      |> Enum.into(%{})

    successful_results = Enum.filter(question_results, fn r -> r.status == :success end)

    %{
      model: "perplexity",
      total_score: model_results["perplexity"].total_score,
      average_score: model_results["perplexity"].average_score,
      questions_processed: model_results["perplexity"].questions_processed,
      successful_questions: length(successful_results),
      status_breakdown: status_counts,
      score_details: %{
        mentioned: Map.get(status_counts, :mentioned, 0),
        no_mention: Map.get(status_counts, :no_mention, 0)
      }
    }
  end

  defp generate_citations_summary(model_results) do
    all_citations =
      model_results["perplexity"].question_results
      |> Enum.flat_map(& &1.citations)
      |> Enum.uniq()

    %{
      total_unique_citations: length(all_citations),
      all_citations: all_citations
    }
  end

  # defp generate_improvement_suggestions(final_score, model_results) do
  #   question_results = model_results["perplexity"].question_results
  #   successful_results = Enum.filter(question_results, fn r -> r.status == :success end)

  #   # Count different statuses
  #   cited_count = Enum.count(successful_results, fn r -> r.domain_status in [:cited_and_mentioned, :cited_only] end)
  #   mentioned_count = Enum.count(successful_results, fn r -> r.domain_status == :mentioned_only end)
  #   no_mention_count = Enum.count(successful_results, fn r -> r.domain_status == :no_mention end)

  #   suggestions = []

  #   # Score-based suggestions
  #   suggestions =
  #     cond do
  #       final_score >= 80 ->
  #         ["Excellent! Your domain has strong visibility in AI responses",
  #          "Keep creating high-quality, authoritative content" | suggestions]

  #       final_score >= 60 ->
  #         ["Good visibility! Focus on maintaining content quality",
  #          "Consider expanding into related topics in your niche" | suggestions]

  #       final_score >= 40 ->
  #         ["Moderate visibility. Work on creating more authoritative content",
  #          "Try to get more quality backlinks from reputable sources" | suggestions]

  #       final_score >= 20 ->
  #         ["Low visibility. Focus on SEO and content marketing",
  #          "Build relationships with other sites in your industry" | suggestions]

  #       true ->
  #         ["Very low visibility. Start with basic SEO optimization",
  #          "Create high-quality content that answers common questions in your field" | suggestions]
  #     end

  #   # Status-based suggestions
  #   suggestions =
  #     cond do
  #       cited_count == 0 ->
  #         ["Your domain is not being cited. Focus on creating citation-worthy content",
  #          "Publish original research or comprehensive guides" | suggestions]

  #       cited_count < length(successful_results) / 2 ->
  #         ["Increase citation frequency by creating more authoritative content",
  #          "Guest post on reputable sites in your industry" | suggestions]

  #       true -> suggestions
  #     end

  #   suggestions =
  #     if no_mention_count > length(successful_results) / 2 do
  #       ["Your domain is not mentioned in many AI responses",
  #        "Improve your content's relevance to common questions in your field" | suggestions]
  #     else
  #       suggestions
  #     end

  #   suggestions
  # end
  defp generate_improvement_suggestions(final_score, model_results) do
    question_results = model_results["perplexity"].question_results
    successful_results = Enum.filter(question_results, fn r -> r.status == :success end)

    # Count mentions
    _mentioned_count = Enum.count(successful_results, fn r -> r.domain_status == :mentioned end)
    no_mention_count = Enum.count(successful_results, fn r -> r.domain_status == :no_mention end)

    suggestions = []

    # Score-based suggestions
    suggestions =
      cond do
        final_score >= 80 ->
          [
            "Excellent! Your brand has strong visibility in AI responses",
            "Keep creating high-quality, authoritative content" | suggestions
          ]

        final_score >= 60 ->
          [
            "Good brand visibility! Focus on maintaining content quality",
            "Consider expanding into related topics in your niche" | suggestions
          ]

        final_score >= 40 ->
          [
            "Moderate brand visibility. Work on creating more authoritative content",
            "Try to get more quality backlinks from reputable sources" | suggestions
          ]

        final_score >= 20 ->
          [
            "Low brand visibility. Focus on SEO and content marketing",
            "Build relationships with other sites in your industry" | suggestions
          ]

        true ->
          [
            "Very low brand visibility. Start with basic SEO optimization",
            "Create high-quality content that answers common questions in your field"
            | suggestions
          ]
      end

    # Mention-based suggestions
    suggestions =
      if no_mention_count > length(successful_results) / 2 do
        [
          "Your brand is not mentioned in many AI responses",
          "Improve your content's relevance to common questions in your field",
          "Focus on building brand awareness through quality content" | suggestions
        ]
      else
        suggestions
      end

    suggestions
  end

  @doc """
  Helper function to add new AI models to the scoring system.
  This function can be used to extend the system with additional models.
  """
  def add_model_weight(model_name, weight) when is_binary(model_name) and is_number(weight) do
    # This would typically update a configuration or database
    # For now, returning the updated weights map
    Map.put(@model_weights, model_name, weight)
  end

  @doc """
  Get current model weights configuration.
  """
  def get_model_weights, do: @model_weights

  @doc """
  Get scoring configuration.
  """
  def get_scoring_config, do: @scoring

  def format_datetime(datetime) when is_struct(datetime, DateTime) do
    datetime
    |> DateTime.to_naive()
    |> NaiveDateTime.to_string()
  end

  def user_activity_status(nil), do: "Inactive"

  def user_activity_status(last_login) when is_struct(last_login, DateTime) do
    one_month_ago = DateTime.utc_now() |> DateTime.add(-30 * 24 * 60 * 60, :second)

    if DateTime.compare(last_login, one_month_ago) == :gt do
      "Active"
    else
      "Inactive"
    end
  end

  def status_color_class(nil),
    do: "inline-flex px-2 py-1 text-xs font-semibold rounded-full bg-red-100 text-red-800"

  def status_color_class(last_login) when is_struct(last_login, DateTime) do
    one_month_ago = DateTime.utc_now() |> DateTime.add(-30 * 24 * 60 * 60, :second)

    if DateTime.compare(last_login, one_month_ago) == :gt do
      "inline-flex px-2 py-1 text-xs font-semibold rounded-full bg-green-100 text-green-800"
    else
      "inline-flex px-2 py-1 text-xs font-semibold rounded-full bg-red-100 text-red-800"
    end
  end

  # defp remove_bold_markers(text) do
  #     # Remove all "**" used for markdown bold
  #     String.replace(text, ~r/\*\*(.*?)\*\*/, "\\1")
  #   end

  # defp remove_citations(text) do
  #   # Remove citations like [1], [2][3], etc.
  #   String.replace(text, ~r/\[(\d+)\](\[\d+\])*/, "")
  # end
end
