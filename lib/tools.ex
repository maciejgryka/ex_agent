defmodule ExAgent.Tools do
  def execute(%{
        "function" => %{"arguments" => args, "name" => function_name},
        "id" => call_id,
        "type" => "function"
      }) do
    with function_name when is_atom(function_name) <- String.to_existing_atom(function_name),
         {:ok, args} <- Jason.decode(args) do
      result = apply(__MODULE__, function_name, [args])
      {:ok, {call_id, result}}
    else
      {:error, reason} -> {:error, {call_id, reason}}
    end
  end

  defp localize(path) do
    Path.join(File.cwd!(), path)
  end

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

  def list_files(%{"path" => path}) do
    path = localize(path)

    if File.exists?(path) do
      File.ls!(path)
    else
      "Error: path does not exist"
    end
  end

  def read_file_schema do
    %{
      type: "function",
      function: %{
        name: "read_file",
        description: "Read the contents of a file.",
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

  def read_file(%{"path" => path}) do
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
        description: """
        Make edits to a text file.

        Replaces 'old_str' with 'new_str' in the file under `path`. 'old_str' and 'new_str' MUST be different from each other.

        If the file specified with path doesn't exist, it will be created. Path is relative to the current working directory.
        """,
        parameters: %{
          type: "object",
          properties: %{
            path: %{type: "string", description: "Path of the file to read"},
            old_str: %{type: "string", description: "old string to replace"},
            new_str: %{type: "string", description: "new string to replace with"}
          },
          additionalProperties: false,
          required: ["path", "old_str", "new_str"]
        },
        strict: true
      }
    }
  end

  def edit_file(%{"path" => path, "old_str" => old_str, "new_str" => new_str}) do
    path = localize(path)

    if File.exists?(path) do
      with {:ok, content} <- File.read(path),
           updated_content = String.replace(content, old_str, new_str),
           :ok <- File.write(path, updated_content) do
        {:ok, updated_content}
      else
        {:error, reason} -> {:error, reason}
      end
    else
      "Error: file does not exist"
    end
  end

  def all_schemas do
    [list_files_schema(), read_file_schema(), edit_file_schema()]
  end
end
