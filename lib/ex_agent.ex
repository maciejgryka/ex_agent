defmodule ExAgent do
  use GenServer

  alias ExAgent.Tools

  require Logger

  @api_host "https://api.openai.com/v1"
  @sys_prompt "You are a helpful coding assistant."

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def prompt(prompt) do
    GenServer.call(__MODULE__, {:prompt, "gpt-4.1-nano", prompt})
  end

  def prompt(pid, model, prompt) do
    GenServer.call(pid, {:prompt, model, prompt})
  end

  def init(_) do
    {:ok, %{history: [%{role: "system", content: @sys_prompt}]}}
  end

  def handle_call({:prompt, model, prompt}, _from, state) do
    state = Map.put(state, :model, model)
    new_messages = [%{role: "user", content: prompt}]
    new_state = continue_chat(state, new_messages)
    {:reply, :ok, new_state}
  end

  defp request(messages, model) do
    case System.get_env("OPENAI_API_KEY") do
      nil ->
        Logger.error("Warning: OPENAI_API_KEY not set")

      api_key ->
        Req.post("#{@api_host}/chat/completions",
          auth: {:bearer, api_key},
          json: %{model: model, messages: messages, tools: Tools.all_schemas()}
        )
    end
  end

  defp continue_chat(state, new_messages) do
    new_history = state.history ++ new_messages

    Task.async(fn ->
      case request(new_history, state.model) do
        {:ok, response} -> send(self(), {:api_response, response})
        {:error, error} -> send(self(), {:api_error, error})
      end
    end)

    %{state | history: new_history}
  end

  def handle_info({_ref, {:api_response, response}}, state) do
    case response.body do
      %{"choices" => [%{"message" => %{"tool_calls" => tool_calls} = message} | _]} ->
        tool_call_results =
          tool_calls
          |> Enum.map(&Tools.execute/1)
          |> Enum.map(fn tool_call_result ->
            case tool_call_result do
              {:ok, result} -> result
              {:error, _} -> nil
            end
          end)
          |> Enum.reject(&is_nil/1)

        send(self(), {:tool_call_results, tool_call_results})

        new_history = state.history ++ [message]

        {:noreply, %{state | history: new_history}}

      %{"choices" => [%{"message" => %{"content" => content}} | _]} ->
        new_history = state.history ++ [%{role: "assistant", content: content}]
        Logger.info("Assistant: #{content}")
        {:noreply, %{state | history: new_history}}

      response_body ->
        Logger.error("Unexpected API response: #{inspect(response_body)}")
        {:noreply, state}
    end
  end

  def handle_info({:api_error, error}, state) do
    Logger.error("API Error: #{inspect(error)}")
    {:noreply, state}
  end

  def handle_info({:tool_call_results, tool_call_results}, state) do
    new_messages =
      Enum.map(tool_call_results, fn {tool_call_id, result} ->
        %{role: "tool", tool_call_id: tool_call_id, content: inspect(result)}
      end)

    new_state = continue_chat(state, new_messages)
    {:noreply, new_state}
  end

  def handle_info({:DOWN, _ref, :process, _pid, :normal}, state) do
    {:noreply, state}
  end
end
