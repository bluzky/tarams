defmodule Tarams do
  @moduledoc """
  Params provide some helpers method to work with parameters
  """

  @doc """
  A plug which do srubbing params

  **Use in Router**

      defmodule MyApp.Router do
        ...
        plug Tarams.plug_srub
        ...
      end

  **Use in controller**

      plug Tarams.plug_srub when action in [:index, :show]
      # or specify which field to scrub
      plug Tarams.plug_srub, ["id", "keyword"] when action in [:index, :show]

  """
  def plug_srub(conn, keys \\ []) do
    params =
      if keys == [] do
        scrub_param(conn.params)
      else
        Enum.reduce(keys, conn.params, fn key, params ->
          case Map.fetch(conn.params, key) do
            {:ok, value} -> Map.put(params, key, scrub_param(value))
            :error -> params
          end
        end)
      end

    %{conn | params: params}
  end

  @doc """
  Convert all parameter which value is empty string or string with all whitespace to nil. It works with nested map and list too.

  **Example**

      params = %{"keyword" => "   ", "email" => "", "type" => "customer"}
      Tarams.scrub_param(params)
      # => %{"keyword" => nil, "email" => nil, "type" => "customer"}

      params = %{user_ids: [1, 2, "", "  "]}
      Tarams.scrub_param(params)
      # => %{user_ids: [1, 2, nil, nil]}
  """
  def scrub_param(%{__struct__: mod} = struct) when is_atom(mod) do
    struct
  end

  def scrub_param(%{} = param) do
    Enum.reduce(param, %{}, fn {k, v}, acc ->
      Map.put(acc, k, scrub_param(v))
    end)
  end

  def scrub_param(param) when is_list(param) do
    Enum.map(param, &scrub_param/1)
  end

  def scrub_param(param) do
    if scrub?(param), do: nil, else: param
  end

  defp scrub?(" " <> rest), do: scrub?(rest)
  defp scrub?(""), do: true
  defp scrub?(_), do: false

  @doc """
  Clean all nil field from params, support nested map and list.

  **Example**

      params = %{"keyword" => nil, "email" => nil, "type" => "customer"}
      Tarams.clean_nil(params)
      # => %{"type" => "customer"}

      params = %{user_ids: [1, 2, nil]}
      Tarams.clean_nil(params)
      # => %{user_ids: [1, 2]}
  """
  @spec clean_nil(any) :: any
  def clean_nil(%{__struct__: mod} = param) when is_atom(mod) do
    param
  end

  def clean_nil(%{} = param) do
    Enum.reduce(param, %{}, fn {k, v}, acc ->
      if is_nil(v) do
        acc
      else
        Map.put(acc, k, clean_nil(v))
      end
    end)
  end

  def clean_nil(param) when is_list(param) do
    Enum.reduce(param, [], fn item, acc ->
      if is_nil(item) do
        acc
      else
        [clean_nil(item) | acc]
      end
    end)
    |> Enum.reverse()
  end

  def clean_nil(param), do: param

  alias Tarams.Type

  @doc """
  Cast and validate params with given schema.
  See `Tarams.Schema` for instruction on how to define a schema
  And then use it like this

  ```elixir
  def index(conn, params) do
    index_schema = %{
      status: [type: :string, required: true],
      type: [type: :string, in: ["type1", "type2", "type3"]],
      keyword: [type: :string, length: [min: 3, max: 100]],
    }

    with {:ok, data} <- Tarams.cast(params, index_schema) do
      # do query data
    else
      {:error, errors} -> IO.puts(errors)
    end
  end
  ```
  """

  @spec cast(data :: map(), schema :: map()) :: {:ok, map()} | {:error, errors :: map()}
  def cast(data, schema) do
    {status, results} =
      schema
      |> Tarams.Schema.expand()
      |> Enum.map(&cast_field(data, &1))
      |> collect_schema_result()

    {status, Map.new(results)}
  end

  defp cast_field(data, {field_name, definitions}) do
    {type, definitions} = Keyword.pop(definitions, :type)
    {default, definitions} = Keyword.pop(definitions, :default)
    {alias, definitions} = Keyword.pop(definitions, :as, field_name)
    {cast_func, validations} = Keyword.pop(definitions, :cast_func)

    value =
      case Map.fetch(data, field_name) do
        {:ok, value} -> value
        _ -> Map.get(data, "#{field_name}", default)
      end

    cast_func =
      if is_function(cast_func) do
        cast_func
      else
        &cast_value(&1, type)
      end

    case cast_func.(value) do
      :error ->
        {:error, {field_name, ["is in valid"]}}

      {:error, errors} ->
        {:error, {field_name, errors}}

      {:ok, data} ->
        validations
        |> Enum.map(fn validation ->
          do_validate(data, validation)
        end)
        |> collect_validation_result()
        |> case do
          :ok -> {:ok, {alias, data}}
          {_, errors} -> {:error, {field_name, errors}}
        end
    end
  end

  defp cast_value(nil, _), do: {:ok, nil}

  # cast array of custom map
  defp cast_value(value, {:array, %{} = type}) do
    cast_array({:embed, __MODULE__, type}, value)
  end

  # cast nested map
  defp cast_value(value, %{} = type) do
    Type.cast({:embed, __MODULE__, type}, value)
  end

  defp cast_value(value, type) do
    Type.cast(type, value)
  end

  # rewrite cast_array for more detail errors
  def cast_array(type, value, acc \\ [])

  def cast_array(type, [value | t], acc) do
    case Type.cast(type, value) do
      {:ok, data} -> cast_array(type, t, [data | acc])
      error -> error
    end
  end

  def cast_array(_, [], acc), do: {:ok, Enum.reverse(acc)}

  defp do_validate(value, {:required, _} = validator) do
    Valdi.validate(value, [validator])
  end

  defp do_validate(nil, _), do: :ok

  defp do_validate(value, validator) do
    Valdi.validate(value, [validator])
  end

  defp collect_validation_result(results) do
    summary =
      Enum.reduce(results, :ok, fn
        :ok, acc -> acc
        {:error, msg}, :ok -> {:error, [msg]}
        {:error, msg}, {:error, acc_msg} -> {:error, [msg | acc_msg]}
      end)

    case summary do
      :ok ->
        :ok

      {:error, errors} ->
        errors =
          errors
          |> Enum.map(fn item ->
            if is_list(item) do
              item
            else
              [item]
            end
          end)
          |> Enum.concat()

        {:error, errors}
    end
  end

  defp collect_schema_result(results) do
    Enum.reduce(results, {:ok, []}, fn
      {:ok, data}, {:ok, acc} -> {:ok, [data | acc]}
      {:error, error}, {:ok, _} -> {:error, [error]}
      {:error, error}, {:error, acc} -> {:error, [error | acc]}
      _, acc -> acc
    end)
  end
end
