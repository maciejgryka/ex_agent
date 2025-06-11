defmodule OpenAI do
  def request(messages, model) do
    case System.get_env("OPENAI_API_KEY") do
      nil ->
        IO.inspect("OPENAI_API_KEY not set", label: "API Error")

      api_key ->
        payload = %{model: model, messages: messages}
        File.write("payload.json", Jason.encode!(payload))

        Req.post(
          "https://api.openai.com/v1/chat/completions",
          auth: {:bearer, api_key},
          json: payload
        )
    end
  end

  def run(%{"choices" => [%{"message" => %{"role" => "assistant", "content" => content}} | _]}) do
    {%{"role" => "assistant", "content" => Jason.encode!(content)}, nil}
  end
end
