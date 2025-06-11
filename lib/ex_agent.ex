defmodule ExAgent do
  @moduledoc false
  use GenServer

  alias ExAgent.Tools

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def prompt(content) do
    GenServer.call(__MODULE__, {:prompt, "gpt-4.1-nano", content})
  end

  def reset, do: GenServer.call(__MODULE__, :reset)

  defp system_prompt do
    cwd = File.cwd!()
    ts = DateTime.to_string(DateTime.utc_now())

    """
    You are a helpful coding assistant.
    You are currently in #{cwd} and it is now #{ts}.
    """
  end

  def init(_) do
    {:ok, %{history: [%{role: "system", content: system_prompt()}]}}
  end

  def handle_call({:prompt, model, content}, _from, state) do
    state = Map.put(state, :model, model)
    new_state = continue_chat(state, [%{role: "user", content: content}])
    {:reply, :ok, new_state}
  end

  def handle_call(:reset, _from, state) do
    {
      :reply,
      :ok,
      %{state | history: [%{role: "system", content: system_prompt()}]}
    }
  end

  def handle_info({_ref, {:api_response, response}}, state) do
    {message, tool_call_results} = OpenAI.run(response.body)
    pretty_print(message)
    new_history = state.history ++ [message]

    if OpenAI.has_tool_calls?(response.body) do
      send(self(), {:tool_call_results, tool_call_results})
    end

    {:noreply, %{state | history: new_history}}
  end

  def handle_info({_ref, {:api_error, error}}, state) do
    IO.inspect(error, label: "API Error")
    {:noreply, state}
  end

  def handle_info({:tool_call_results, tool_call_results}, state) do
    new_messages =
      Enum.map(tool_call_results, fn {tool_call_id, result} ->
        %{
          role: "tool",
          tool_call_id: tool_call_id,
          content: Jason.encode!(result)
        }
      end)

    {:noreply, continue_chat(state, new_messages)}
  end

  def handle_info({:DOWN, _ref, :process, _pid, :normal}, state) do
    {:noreply, state}
  end

  defp continue_chat(state, new_messages) do
    IO.inspect(new_messages, label: "Continue chat")
    new_history = state.history ++ new_messages

    Task.async(fn ->
      case OpenAI.request(new_history, state.model, Tools.all_schemas()) do
        {:ok, response} -> send(self(), {:api_response, response})
        {:error, error} -> send(self(), {:api_error, error})
      end
    end)

    %{state | history: new_history}
  end

  defp pretty_print(%{"role" => "assistant", "tool_calls" => tool_calls}) do
    IO.inspect(tool_calls, label: "Tool Calls")
  end

  defp pretty_print(%{"role" => "assistant", "content" => content}) do
    IO.puts("Assistant: #{content}")
  end
end
