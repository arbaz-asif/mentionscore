defmodule MentionScoreWeb.CallbackController do
  use MentionScoreWeb, :controller
  plug Ueberauth

  alias MentionScoreWeb.UserAuth
  alias MentionScore.Users

  def request(conn, %{"provider" => provider}) do
    redirect(conn, to: Ueberauth.Strategy.Helpers.callback_url(conn, provider))
  end

  def callback(%{assigns: %{ueberauth_auth: auth}} = conn, _params) do
    case Users.get_user_by_email(auth.info.email) do
      nil ->
        user_params = %{
          "first_name" => auth.info.first_name,
          "last_name" => auth.info.last_name,
          "email" => auth.info.email
        }

        case Users.register_user_via_google(user_params) do
          {:ok, user} ->
            conn
            |> UserAuth.log_in_user(user, %{})

          _ ->
            conn
            |> put_flash(:error, "Login failed. Please try again")
            |> redirect(to: "/users/log_in")
        end

      user ->
        conn
        |> UserAuth.log_in_user(user, %{})
    end
  end

  def callback(
        %{assigns: %{ueberauth_failure: %Ueberauth.Failure{errors: _errors}}} = conn,
        _params
      ) do
    conn
    |> put_flash(:error, "Login failed. Please try again")
    |> redirect(to: "/users/log_in")
  end

  def gumroad_callback(conn, %{"email" => email, "product_name" => product_name}) do
    if Users.is_user_exist?(email) &&
         product_name in ["Starter", "Growth", "Agency"] do
      user = Users.get_user_by_email(email)
      credits = get_credits(product_name) + user.credits
      Users.update_user(user, %{"credits" => credits})

      conn
      |> put_flash(:info, "#{get_credits(product_name)} credits bought successfully!")
      |> redirect(to: ~p"/dashboard")
    else
      conn
      |> put_flash(:error, "Unable to buy credits. Please try again")
      |> redirect(to: ~p"/dashboard")
    end
  end

  def gumroad_callback(conn, _params) do
    conn
    |> put_flash(:error, "Unable to buy credits. Please try again")
    |> redirect(to: ~p"/dashboard")
  end

  def get_credits(product_name) do
    case product_name do
      "Starter" -> 50
      "Growth" -> 100
      _ -> 150
    end
  end
end
