defmodule Tarams do
  @moduledoc """
  Params provide some helpers method to work with parameters
  """

  @doc """
  A plug which do srubbing params

  **Use in Router**

      defmodule MyApp.Router do
        ...
        plug Tarams.plug_scrub
        ...
      end

  **Use in controller**

      plug Tarams.plug_scrub when action in [:index, :show]
      # or specify which field to scrub
      plug Tarams.plug_scrub, ["id", "keyword"] when action in [:index, :show]

  """
  def plug_scrub(conn, keys \\ []) do
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
    {alias, definitions} = Keyword.pop(definitions, :as, field_name)
    {custom_message, definitions} = Keyword.pop(definitions, :message)

    # remote transform option from definition
    validations = Keyword.drop(definitions, [:into, :type, :cast_func, :default])

    # 1. cast value
    with {:ok, value} <- do_cast(data, field_name, definitions),
         # 2. apply validation
         :ok <- apply_validations(value, validations),
         {:ok, value} <- apply_transform(value, definitions, data) do
      {:ok, {alias, value}}
    else
      {:error, error} ->
        # 3.2 Handle custom error message
        if custom_message do
          {:error, {field_name, [custom_message]}}
        else
          errors = if is_binary(error), do: [error], else: error

          {:error, {field_name, errors}}
        end
    end
  end

  # cast data to proper type
  defp do_cast(data, field_name, definitions) do
    value =
      case Map.fetch(data, field_name) do
        {:ok, value} -> value
        _ -> Map.get(data, "#{field_name}", definitions[:default])
      end

    cast_result =
      case definitions[:cast_func] do
        nil ->
          cast_value(value, definitions[:type])

        func when is_function(func, 1) ->
          func.(value)

        func when is_function(func, 2) ->
          func.(value, data)

        {mod, func} when is_atom(mod) and is_atom(func) ->
          apply(mod, func, [value, data])

        _ ->
          {:error, "invalid cast function"}
      end

    case cast_result do
      :error -> {:error, "is invalid"}
      others -> others
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

  # apply list of validation to value
  defp apply_validations(value, validations) do
    validations
    |> Enum.map(fn validation ->
      do_validate(value, validation)
    end)
    |> collect_validation_result()
  end

  # handle custom validation for required
  defp do_validate(value, {:required, _} = validator) do
    Valdi.validate(value, [validator])
  end

  # skip validation for nil
  defp do_validate(nil, _), do: :ok

  defp do_validate(value, validator) do
    Valdi.validate(value, [validator])
  end

  # transform data
  defp apply_transform(value, definitions, data) do
    case definitions[:into] do
      nil ->
        {:ok, value}

      {mod, func} when is_atom(mod) and is_atom(func) ->
        apply(mod, func, [value, data])

      func when is_function(func, 1) ->
        func.(value)

      func when is_function(func, 2) ->
        func.(value, data)

      _ ->
        {:error, "invalid transform function"}
    end
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
