defmodule MentionScore.Gumroad do
  @gumroad_base_url "https://api.gumroad.com/v2"

  def get_products() do
    url = "#{@gumroad_base_url}/products"

    query_params =
      URI.encode_query(%{"access_token" => System.get_env("GUMROAD_ACCESS_TOKEN")})

    full_url = "#{url}?#{query_params}"

    call_api(:get, full_url)
  end

  defp call_api(method, url) do
    case Finch.build(method, url)
         |> Finch.request(MentionScore.Finch) do
      {:ok, %Finch.Response{status: status, body: body}} when status in 200..299 ->
        {:ok, format_response(body)}

      {:ok, %Finch.Response{status: status, body: body}} ->
        {:error, status, format_response(body)}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp format_response(body) do
    case Jason.decode(body) do
      {:ok, decoded_body} -> decoded_body
      {:error, reason} -> reason
    end
  end
end
