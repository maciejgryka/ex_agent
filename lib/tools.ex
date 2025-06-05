defmodule ExAgent.Tools do
  def execute(%{
        "function" => %{"arguments" => args, "name" => function_name},
        "id" => call_id,
        "type" => "function"
      }) do
    with function_name when is_atom(function_name) <- String.to_existing_atom(function_name),
         {:ok, args} <- Jason.decode(args) do
      result = apply(__MODULE__, function_name, Map.values(args))
      {:ok, {call_id, result}}
    else
      {:error, reason} -> {:error, {call_id, reason}}
    end
  end

  def list_dir_schema do
    %{
      type: "function",
      function: %{
        name: "list_dir",
        description: "List files in a directory.",
        parameters: %{
          type: "object",
          properties: %{path: %{type: "string", description: "Path to the directory"}},
          additionalProperties: false,
          required: ["path"]
        },
        strict: true
      }
    }
  end

  def list_dir(path) do
    if File.exists?(path) do
      File.ls!(path)
    else
      "Error: path does not exist"
    end
  end

  def all_schemas do
    [list_dir_schema()]
  end
end
