defmodule OpenAI do
  alias ExAgent.Tools

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
          json: payload,
          receive_timeout: 60_000
        )
    end
  end

  def run(%{"choices" => [%{"message" => %{"tool_calls" => tool_calls} = message}]}) do
    tool_call_results =
      tool_calls
      |> Enum.map(&Tools.execute/1)
      |> Enum.map(fn
        {:ok, result} -> result
        {:error, _} -> nil
      end)
      |> Enum.reject(&is_nil/1)

    {message, tool_call_results}
  end

  def run(%{"choices" => [%{"message" => %{"role" => "assistant", "content" => content}} | _]}) do
    {%{"role" => "assistant", "content" => content}, nil}
  end

  def has_tool_calls?(%{"choices" => [%{"message" => %{"tool_calls" => _tool_calls}} | _]}) do
    true
  end

  def has_tool_calls?(_), do: false
end
