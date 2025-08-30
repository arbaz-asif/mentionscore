defmodule MentionScoreWeb.UserRegistrationLive do
  use MentionScoreWeb, :live_view

  alias MentionScore.Users
  alias MentionScore.Users.User

  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-white flex">
      <!-- Left Section - Branding & Illustration -->
      <div class="hidden lg:flex lg:w-1/2 bg-gradient-to-br from-gray-50 to-gray-100 flex-col justify-center items-center px-12 relative overflow-hidden">
        <!-- Background Pattern -->
        <div class="absolute inset-0 opacity-5">
          <svg width="100%" height="100%" xmlns="http://www.w3.org/2000/svg">
            <defs>
              <pattern id="grid" width="40" height="40" patternUnits="userSpaceOnUse">
                <path d="M 40 0 L 0 0 0 40" fill="none" stroke="black" stroke-width="1" />
              </pattern>
            </defs>
            <rect width="100%" height="100%" fill="url(#grid)" />
          </svg>
        </div>
        
    <!-- Logo -->
        <div class="text-center mb-12 z-10">
          <div class="text-6xl font-bold text-black mb-6">
            <img src={~p"/images/ms-logo.png"} class="mx-auto h-auto" alt="Logo" />
          </div>
          <p class="text-xl text-gray-600 max-w-md leading-relaxed">
            Optimize your brand's visibility in generative AI search results
          </p>
        </div>
        
    <!-- Feature highlights -->
        <div class="mt-8 space-y-3 z-10">
          <div class="flex items-center space-x-3">
            <div class="w-2 h-2 bg-black rounded-full"></div>
            <span class="text-gray-700">Track AI-generated search mentions</span>
          </div>
          <div class="flex items-center space-x-3">
            <div class="w-2 h-2 bg-black rounded-full"></div>
            <span class="text-gray-700">Optimize for generative engines</span>
          </div>
          <div class="flex items-center space-x-3">
            <div class="w-2 h-2 bg-black rounded-full"></div>
            <span class="text-gray-700">Monitor competitor performance</span>
          </div>
        </div>
      </div>
      
    <!-- Right Section - Signup Form -->
      <div class="w-full lg:w-1/2 flex items-center justify-center px-4 py-8">
        <div class="w-full max-w-md">
          <!-- Mobile Logo (only visible on small screens) -->
          <div class="text-center mb-8 lg:hidden">
            <h1 class="text-4xl font-bold text-black mb-2">
              MentionScore
            </h1>
          </div>
          
    <!-- Google Sign In Button -->
          <a href="/auth/google">
            <button class="w-full bg-white border border-gray-300 rounded-xl px-4 py-3 text-gray-700 font-medium hover:bg-gray-50 transition-all duration-200 flex items-center justify-center space-x-3 shadow-sm mb-2">
              <svg class="w-5 h-5" viewBox="0 0 24 24">
                <path
                  fill="#4285F4"
                  d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92c-.26 1.37-1.04 2.53-2.21 3.31v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.09z"
                />
                <path
                  fill="#34A853"
                  d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z"
                />
                <path
                  fill="#FBBC05"
                  d="M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.07H2.18C1.43 8.55 1 10.22 1 12s.43 3.45 1.18 4.93l2.85-2.22.81-.62z"
                />
                <path
                  fill="#EA4335"
                  d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.07l3.66 2.84c.87-2.6 3.3-4.53 6.16-4.53z"
                />
              </svg>
              <span>Continue with Google</span>
            </button>
          </a>
          
    <!-- Divider -->
          <div class="relative mb-2">
            <div class="absolute inset-0 flex items-center">
              <div class="w-full border-t border-gray-200"></div>
            </div>
            <div class="relative flex justify-center text-sm">
              <span class="px-4 bg-white text-gray-500">Or create your account</span>
            </div>
          </div>
          
    <!-- Signup Form Card -->
          <div class="bg-white border border-gray-200 rounded-2xl py-6 px-8 shadow-sm">
            <!-- Header -->
            <div class="text-center mb-2">
              <h2 class="text-2xl font-bold text-black mb-2">Create Your Account</h2>
              <p class="text-gray-600">
                Already registered?
                <a href="/users/log_in" class="font-semibold text-black hover:underline ml-1">
                  Log in
                </a>
                to your account now.
              </p>
            </div>
            
    <!-- Registration Form -->
            <.simple_form
              for={@form}
              id="registration_form"
              phx-submit="save"
              phx-change="validate"
              phx-trigger-action={@trigger_submit}
              action={~p"/users/log_in?_action=registered"}
              method="post"
            >
              <div class="space-y-5">
                <div class="grid grid-cols-2 gap-4">
                  <div>
                    <label class="block text-sm font-medium text-gray-700 mb-2">
                      First Name
                    </label>
                    <.input
                      field={@form[:first_name]}
                      type="text"
                      placeholder="First name"
                      class="w-full bg-white border border-gray-300 rounded-xl px-4 py-3 text-black placeholder-gray-400 focus:outline-none focus:ring-2 focus:ring-black focus:border-transparent"
                      required
                    />
                  </div>

                  <div>
                    <label class="block text-sm font-medium text-gray-700 mb-2">
                      Last Name
                    </label>
                    <.input
                      field={@form[:last_name]}
                      type="text"
                      placeholder="Last name"
                      class="w-full bg-white border border-gray-300 rounded-xl px-4 py-3 text-black placeholder-gray-400 focus:outline-none focus:ring-2 focus:ring-black focus:border-transparent"
                      required
                    />
                  </div>
                </div>

                <div>
                  <label class="block text-sm font-medium text-gray-700 mb-2">
                    Email Address
                  </label>
                  <.input
                    field={@form[:email]}
                    type="email"
                    placeholder="Enter your email address"
                    class="w-full bg-white border border-gray-300 rounded-xl px-4 py-3 text-black placeholder-gray-400 focus:outline-none focus:ring-2 focus:ring-black focus:border-transparent"
                    required
                  />
                </div>

                <div class="grid grid-cols-2 gap-4">
                  <div>
                    <label class="block text-sm font-medium text-gray-700 mb-2">
                      Password
                    </label>
                    <.input
                      field={@form[:password]}
                      type="password"
                      placeholder="Create password"
                      class="w-full bg-white border border-gray-300 rounded-xl px-4 py-3 text-black placeholder-gray-400 focus:outline-none focus:ring-2 focus:ring-black focus:border-transparent"
                      required
                    />
                  </div>

                  <div>
                    <label class="block text-sm font-medium text-gray-700 mb-2">
                      Confirm Password
                    </label>
                    <.input
                      field={@form[:confirm_password]}
                      type="password"
                      placeholder="Confirm password"
                      class="w-full bg-white border border-gray-300 rounded-xl px-4 py-3 text-black placeholder-gray-400 focus:outline-none focus:ring-2 focus:ring-black focus:border-transparent"
                      required
                    />
                  </div>
                </div>
              </div>

              <:actions>
                <.button
                  phx-disable-with="Creating account..."
                  class="w-full py-3 bg-black text-white rounded-xl font-medium hover:bg-gray-800 transition-all duration-200 transform hover:scale-105 focus:outline-none focus:ring-2 focus:ring-gray-400"
                >
                  Create Account
                </.button>
              </:actions>
            </.simple_form>
          </div>
        </div>
      </div>
      <!--Start of Tawk.to Script-->
      <script type="text/javascript">
        var Tawk_API=Tawk_API||{}, Tawk_LoadStart=new Date();
        (function(){
        var s1=document.createElement("script"),s0=document.getElementsByTagName("script")[0];
        s1.async=true;
        s1.src='https://embed.tawk.to/684d954060401c1911854fe6/1itngu108';
        s1.charset='UTF-8';
        s1.setAttribute('crossorigin','*');
        s0.parentNode.insertBefore(s1,s0);
        })();
      </script>
      <!--End of Tawk.to Script-->
    </div>
    """
  end

  def mount(_params, _session, socket) do
    changeset = Users.change_user_registration(%User{})

    socket =
      socket
      |> assign(trigger_submit: false, check_errors: false)
      |> assign_form(changeset)

    {:ok, socket, temporary_assigns: [form: nil]}
  end

  def handle_event("save", %{"user" => user_params}, socket) do
    case Users.register_user(user_params) do
      {:ok, user} ->
        # {:ok, _} =
        # Users.deliver_user_confirmation_instructions(
        #   user,
        #   &url(~p"/users/confirm/#{&1}")
        # )

        changeset = Users.change_user_registration(user)
        {:noreply, socket |> assign(trigger_submit: true) |> assign_form(changeset)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, socket |> assign(check_errors: true) |> assign_form(changeset)}
    end
  end

  def handle_event("validate", %{"user" => user_params}, socket) do
    changeset = Users.change_user_registration(%User{}, user_params)
    {:noreply, assign_form(socket, Map.put(changeset, :action, :validate))}
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    form = to_form(changeset, as: "user")

    if changeset.valid? do
      assign(socket, form: form, check_errors: false)
    else
      assign(socket, form: form)
    end
  end
end
