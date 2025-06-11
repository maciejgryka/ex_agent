defmodule OpenAI do
  def request(messages, model, tools \\ nil) do
    case System.get_env("OPENAI_API_KEY") do
      nil ->
        IO.inspect("OPENAI_API_KEY not set", label: "API Error")

      api_key ->
        payload =
          case tools do
            nil -> %{model: model, messages: messages}
            tools -> %{model: model, messages: messages, tools: tools}
          end

        File.write("payload.json", Jason.encode!(payload))

        Req.post(
          "https://api.openai.com/v1/chat/completions",
          auth: {:bearer, api_key},
          json: payload
        )
    end
  end
end
