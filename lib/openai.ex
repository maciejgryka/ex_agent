defmodule OpenAI do
  @moduledoc false
  require Logger

  @api_host "https://api.openai.com/v1"

  def request(messages, model, tools \\ nil) do
    case System.get_env("OPENAI_API_KEY") do
      nil ->
        Logger.error("Warning: OPENAI_API_KEY not set")

      api_key ->
        payload = %{model: model, messages: messages}

        payload =
          case tools do
            nil -> payload
            tools -> Map.put(payload, :tools, tools)
          end

        Req.post("#{@api_host}/chat/completions", auth: {:bearer, api_key}, json: payload)
    end
  end
end
