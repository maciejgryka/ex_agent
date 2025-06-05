defmodule ExAgent do
  use GenServer

  require Logger

  @api_host "https://api.openai.com/v1"
  @sys_prompt "You are a helpful assistant."

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
    new_state = continue_chat(state, model, prompt)
    {:reply, :ok, new_state}
  end

  defp request(messages, model) do
    case System.get_env("OPENAI_API_KEY") do
      nil ->
        Logger.error("Warning: OPENAI_API_KEY not set")

      api_key ->
        Req.post("#{@api_host}/chat/completions",
          auth: {:bearer, api_key},
          json: %{model: model, messages: messages}
        )
    end
  end

  defp continue_chat(state, model, prompt) do
    new_history = state.history ++ [%{role: "user", content: prompt}]

    Task.async(fn ->
      case request(new_history, model) do
        {:ok, response} -> send(self(), {:api_response, response})
        {:error, error} -> send(self(), {:api_error, error})
      end
    end)

    %{state | history: new_history}
  end

  def handle_info({_ref, {:api_response, response}}, state) do
    case response.body do
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

  def handle_info({:DOWN, _ref, :process, _pid, :normal}, state) do
    {:noreply, state}
  end

  # defp invoke_tool(_api_resp) do
  #   "testing tool output"
  # end
end
