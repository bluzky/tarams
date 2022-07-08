defmodule Tarams do
  @moduledoc """
  Params provide some helpers method to work with parameters
  """

  alias Tarams.Type

  defdelegate plug_scrub(conn, keys \\ []), to: Tarams.Utils
  defdelegate scrub_param(data), to: Tarams.Utils
  defdelegate clean_nil(data), to: Tarams.Utils

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
    schema = schema |> Tarams.Schema.expand()

    with {:ok, data} <- cast_data(data, schema),
         data <- Map.new(data),
         :ok <- validate_data(data, schema),
         {:ok, data} <- transform_data(data, schema) do
      {:ok, Map.new(data)}
    else
      {:error, errors} -> {:error, Map.new(errors)}
    end
  end

  def cast!(data, schema) do
    case cast(data, schema) do
      {:ok, value} -> value
      _ -> raise "Tarams :: bad input data"
    end
  end

  defp cast_data(data, schema) do
    schema
    |> Enum.map(&cast_field(data, &1))
    |> collect_schema_result()
  end

  defp validate_data(data, schema) do
    schema
    |> Enum.map(&validate_field(data, &1))
    |> collect_schema_result()
    |> case do
      {:error, errors} -> {:error, Map.new(errors)}
      _ -> :ok
    end
  end

  defp transform_data(data, schema) do
    schema
    |> Enum.map(&transform_field(data, &1))
    |> collect_schema_result()
  end

  defp cast_field(data, {field_name, definitions}) do
    {custom_message, definitions} = Keyword.pop(definitions, :message)

    # 1. cast value
    with {:ok, value} <- do_cast(data, field_name, definitions) do
      {:ok, {field_name, value}}
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
    field_name =
      if definitions[:from] do
        definitions[:from]
      else
        field_name
      end

    value = get_value(data, field_name, definitions[:default])

    cast_result =
      case definitions[:cast_func] do
        nil ->
          cast_value(value, definitions[:type])

        func ->
          apply_function(func, value, data)
      end

    case cast_result do
      :error -> {:error, "is invalid"}
      others -> others
    end
  end

  defp get_value(data, field_name, default \\ nil) do
    case Map.fetch(data, field_name) do
      {:ok, value} ->
        value

      _ ->
        case Map.fetch(data, "#{field_name}") do
          {:ok, value} ->
            value

          _ ->
            default
        end
    end
  end

  defp cast_value("", %{} = type), do: cast_value(%{}, type)
  defp cast_value(nil, %{} = type), do: cast_value(%{}, type)
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

  @validation_ignore [:into, :type, :cast_func, :default, :from, :message, :as]
  defp validate_field(data, {field_name, definitions}) do
    value = get_value(data, field_name)
    # remote transform option from definition
    Keyword.drop(definitions, @validation_ignore)
    |> Enum.map(fn validation ->
      do_validate(value, data, validation)
    end)
    |> collect_validation_result()
    |> case do
      {:error, errors} -> {:error, {field_name, errors}}
      :ok -> :ok
    end
  end

  # handle custom validation for required
  # Support dynamic require validation
  defp do_validate(value, data, {:required, required}) do
    if is_boolean(required) do
      Valdi.validate(value, [{:required, required}])
    else
      case apply_function(required, value, data) do
        {:error, _} = error ->
          error

        rs ->
          is_required = rs not in [false, nil]
          Valdi.validate(value, [{:required, is_required}])
      end
    end
  end

  # skip validation for nil
  defp do_validate(nil, _, _), do: :ok

  # support custom validate fuction with whole data
  defp do_validate(value, data, {:func, func}) do
    case func do
      {mod, func} -> apply(mod, func, [value, data])
      {mod, func, args} -> apply(mod, func, args ++ [value, data])
      func when is_function(func) -> func.(value)
      _ -> {:error, "invalid custom validation function"}
    end
  end

  defp do_validate(value, _, validator) do
    Valdi.validate(value, [validator])
  end

  defp transform_field(data, {field_name, definitions}) do
    value = get_value(data, field_name)
    field_name = definitions[:as] || field_name

    result =
      case definitions[:into] do
        nil ->
          {:ok, value}

        func ->
          apply_function(func, value, data)
      end

    # support function return tuple or value
    case result do
      {status, value} when status in [:error, :ok] -> {status, {field_name, value}}
      value -> {:ok, {field_name, value}}
    end
  end

  # Apply custom function for validate, cast, and required
  defp apply_function(func, value, data) do
    case func do
      {mod, func} ->
        cond do
          Kernel.function_exported?(mod, func, 1) ->
            apply(mod, func, [value])

          Kernel.function_exported?(mod, func, 2) ->
            apply(mod, func, [value, data])

          true ->
            {:error, "bad function"}
        end

      func when is_function(func, 2) ->
        func.(value, data)

      func when is_function(func, 1) ->
        func.(value)

      _ ->
        {:error, "bad function"}
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
