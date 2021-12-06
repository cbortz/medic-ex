defmodule Medic.Check do
  @moduledoc "Reusable check functions"

  alias Medic.UI

  @typedoc """
  Valid return values from a check.

  * `:ok` - The check succeeded with no problems.
  * `:skipped` - Doctor checks for files in `.medic/skipped/` to skip a check. Custom
    checks could return this to notify Doctor that they chose internally to skip the check.
  * `{:warn, output}` - The check generated warnings, but does not stop Doctor from proceeding.
  * `{:error, output, remedy}` - The check failed. Output may be `stdout` and/or `stderr` generated
    from shell commands, or custom error output to show to the user. The `remedy` will by copied
    into the local paste buffer.
  """
  @type check_return_t() ::
          :ok
          | :skipped
          | {:warn, output :: binary}
          | {:error, output :: binary, remedy :: binary}

  @doc false
  def run({module, meta_function}),
    do: run({module, meta_function, []})

  @doc false
  def run({module, function, args}) do
    UI.item(
      module |> Module.split() |> List.last(),
      function |> to_string() |> String.replace("_", " "),
      args
    )

    if skipped?(module, function, args) do
      :skipped
    else
      apply(module, function, wrap(args))
    end
  end

  @doc """
  Usable within a check. If the command exits with a 0 status code, then `:ok`, is returned.
  If the command returns a non-zero status code, then `{:error, output, remedy}` is returned,
  where output is any text generated by the command.
  """
  @spec command_succeeds?(binary(), list(binary()), remedy: binary()) :: :ok | {:error, binary(), binary()}
  def command_succeeds?(command, args, remedy: remedy) do
    case System.cmd(command, args) do
      {_output, 0} -> :ok
      {output, _} -> {:error, output, remedy}
    end
  end

  def in_list?(item, list, remedy: remedy),
    do: if(item in list, do: :ok, else: {:error, "“#{item}” not found in #{inspect(list)}", remedy})

  def skipped?(module, function, args),
    do:
      {module, function, args}
      |> skip_file()
      |> File.exists?()

  def skip_file({module, function}), do: skip_file({module, function, []})

  def skip_file({module, function, args}) do
    arg_list =
      if Keyword.keyword?(args) do
        args |> Keyword.values() |> Enum.join("+")
      else
        args |> Enum.join("+")
      end

    filename =
      [module, function, arg_list]
      |> Enum.filter(fn
        "" -> false
        _ -> true
      end)
      |> Enum.join("-")
      |> String.replace(~r{[^\w\-_\+\.]+}, "")

    Path.join(".medic/skipped", filename)
  end

  defp wrap(args) do
    if Keyword.keyword?(args) and args != [] do
      [args]
    else
      args
    end
  end
end
