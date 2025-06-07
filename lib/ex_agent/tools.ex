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

  def find_schema do
    %{
      type: "function",
      function: %{
        name: "find",
        description: "Find files using the unix `find` command.",
        parameters: %{
          type: "object",
          properties: %{
            path: %{
              type: "string",
              description: "Path to start finding from, relative to the current working directory"
            },
            pattern: %{type: "string", description: "Filename pattern to find"}
          },
          additionalProperties: false,
          required: ["path", "pattern"]
        },
        strict: true
      }
    }
  end

  def find(%{path: path, pattern: pattern}) do
    path = localize(path)

    if File.dir?(path) do
      {result, 0} = System.cmd("find", [path, "-name", pattern])
      String.split(String.trim(result), "\n")
    else
      "Error: path is not a directory"
    end
  end

  def regex_search_schema do
    %{
      type: "function",
      function: %{
        name: "regex_search",
        description:
          "Search for matches of a regex pattern in files using the `rg` (ripgrep) command. Returns a list of file paths with line numbers where matches occur.",
        parameters: %{
          type: "object",
          properties: %{
            path: %{
              type: "string",
              description: "Path to start searching from, relative to the current working directory"
            },
            pattern: %{type: "string", description: "Regex pattern to match"}
          },
          additionalProperties: false,
          required: ["path", "pattern"]
        },
        strict: true
      }
    }
  end

  def regex_search(%{path: path, pattern: pattern}) do
    path = localize(path)

    if File.dir?(path) do
      {result, _} =
        System.cmd("rg", ["--json", "-n", "-H", "--color", "never", "-s", pattern, path])

      # Parse lines of JSON from ripgrep output
      results =
        result
        |> String.split("\n", trim: true)
        |> Enum.filter(&(&1 != ""))
        |> Enum.map(fn line ->
          case Jason.decode(line) do
            {:ok,
             %{
               "type" => "match",
               "data" => %{"lines" => %{"text" => text}, "line_number" => line_number, "path" => %{"text" => file}}
             }} ->
              {file, line_number, text}

            _ ->
              nil
          end
        end)
        |> Enum.reject(&is_nil/1)

      results
      |> Enum.map(fn {file, line_number, _text} -> "#{file}:#{line_number}" end)
      |> Enum.uniq()
    else
      "Error: path is not a directory"
    end
  end

  def all_schemas do
    [list_files_schema(), read_file_schema(), edit_file_schema(), find_schema(), regex_search_schema()]
  end
end
