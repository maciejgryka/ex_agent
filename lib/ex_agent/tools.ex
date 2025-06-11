defmodule ExAgent.Tools do
  @moduledoc false

  defp parse_args(args_str) do
    with {:ok, args} <- Jason.decode(args_str) do
      Map.new(args, fn {k, v} -> {String.to_existing_atom(k), v} end)
    end
  end

  def execute(%{"function" => %{"arguments" => args, "name" => function_name}, "id" => call_id, "type" => "function"}) do
    with function_name when is_atom(function_name) <- String.to_existing_atom(function_name),
         args when is_map(args) <- parse_args(args) do
      result = apply(__MODULE__, function_name, [args])
      {:ok, {call_id, result}}
    else
      {:error, reason} -> {:error, {call_id, reason}}
    end
  end

  defp localize(path), do: Path.join(File.cwd!(), path)

  def list_files_schema do
    %{
      type: "function",
      function: %{
        name: "list_files",
        description: "List files in a given directory.",
        parameters: %{
          type: "object",
          properties: %{
            path: %{
              type: "string",
              description: "Path to the directory, relative to the current working directory"
            }
          },
          additionalProperties: false,
          required: ["path"]
        },
        strict: true
      }
    }
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
    %{
      type: "function",
      function: %{
        name: "read_file",
        description:
          "Read the contents of a file. No need to check for file existance: if if does not exist, an error message is returned.",
        parameters: %{
          type: "object",
          properties: %{
            path: %{
              type: "string",
              description: "Path of the file to read, relative to the current working directory"
            }
          },
          additionalProperties: false,
          required: ["path"]
        },
        strict: true
      }
    }
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
    %{
      type: "function",
      function: %{
        name: "edit_file",
        description: "Edit the contents of a file by replacing a substring (old_str) with a new substring (new_str).",
        parameters: %{
          type: "object",
          properties: %{
            path: %{
              type: "string",
              description: "Path of the file to edit, relative to the current working directory"
            },
            old_str: %{
              type: "string",
              description: "The string to be replaced in the file. MUST but unique."
            },
            new_str: %{
              type: "string",
              description: "The string to replace old_str with"
            }
          },
          additionalProperties: false,
          required: ["path", "old_str", "new_str"]
        },
        strict: true
      }
    }
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
