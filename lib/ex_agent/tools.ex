defmodule ExAgent.Tools do
  @moduledoc false

  defp parse_args(args_str) do
    with {:ok, args} <- Jason.decode(args_str) do
      Map.new(args, fn {k, v} -> {String.to_existing_atom(k), v} end)
    end
  end

  def execute(%{
        "type" => "function",
        "id" => call_id,
        "function" => %{"arguments" => args, "name" => function_name}
      }) do
    with function_name <- String.to_existing_atom(function_name),
         args when is_map(args) <- parse_args(args) do
      result = apply(__MODULE__, function_name, [args])
      {:ok, {call_id, result}}
    else
      {:error, reason} -> {:error, {call_id, reason}}
    end
  end

  defp localize(path), do: Path.join(File.cwd!(), path)

  def list_files_schema do
    %{}
  end

  def list_files(%{path: path}) do
    path = localize(path)

    if File.dir?(path) do
      File.ls!(path)
    else
      "Error: path is not a directory"
    end
  end

  def read_file_schema do
    %{}
  end

  def read_file(%{path: path}) do
    path = localize(path)

    if File.exists?(path) do
      File.read!(path)
    else
      "Error: file does not exist"
    end
  end

  def edit_file_schema do
    %{}
  end

  def edit_file(%{path: path, old_str: old_str, new_str: new_str}) do
    path = localize(path)

    with true <- File.exists?(path),
         {:ok, content} <- File.read(path),
         1 <- count_occurrences(content, old_str),
         updated_content = String.replace(content, old_str, new_str),
         :ok <- File.write(path, updated_content) do
      updated_content
    else
      false -> "Error: file does not exist"
      0 -> "Error: old_str not found"
      occ when occ > 1 -> "Error: old_str is not unique"
    end
  end

  def count_occurrences(content, substring) do
    parts =
      content
      |> String.split(substring, include_captures: true)
      |> Enum.count()

    parts - 1
  end

  def all_schemas do
    [list_files_schema(), read_file_schema(), edit_file_schema()]
  end
end
