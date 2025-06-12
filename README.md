# Presentation plan

## Intro: what is an agent?

## Make OpenAI requests
- `stage-1`
- open a fresh project
- open https://platform.openai.com/docs/api-reference/chat/create
- make a simple OpenAI API request: `OpenAI.request([%{"role" => "user", "content" => "tell me a joke"}], "gpt-4.1-nano")`

## Chat
- `stage-2`
- write `ex_agent.ex` and `openai.ex`
-
```
ExAgent.prompt("tell me a joke")
ExAgent.prompt("now one, with the word 'elixir'")
ExAgent.prompt("now one, with the word 'python'")
```

## Tool calls
- `main`
```
ExAgent.prompt("""
  generate openai api tool call schema for the following elixir function; make sure it's strict mode and doesn't allow additional parameters:

  def list_files(%{path: path}) do
      path = localize(path)

      if File.dir?(path) do
        File.ls!(path)
      else
        "Error: path is not a directory"
      end
    end
  """
)
```

```
ExAgent.prompt("""
  generate openai api tool call schema for the following elixir function; make sure it's strict mode and doesn't allow additional parameters:

  def read_file(%{path: path}) do
    path = localize(path)

    if File.exists?(path) do
      File.read!(path)
    else
      "Error: file does not exist"
    end
  end
  """
)
```

## Answering questions about code

```
ExAgent.prompt("what does this project do?")
ExAgent.prompt("how would you improve this?")
```

## Editing + more tools

- `added-find-and-regex-search`
