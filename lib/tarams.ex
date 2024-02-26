defmodule Tarams do
  @moduledoc """
  Params provide some helpers method to work with parameters
  """

  alias Tarams.Type
  alias Tarams.Result

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

  @spec cast(data :: map(), schema :: map()) ::
          {:ok, map()} | {:error, errors :: map()}
  def cast(data, schema) do
    schema = schema |> Tarams.Schema.expand()

    Result.new(schema: schema, params: data)
    |> do_cast()
    |> do_validate()
    |> do_transform()
    |> case do
      %Result{valid?: true, valid_data: valid_data} -> {:ok, valid_data}
      %{errors: errors} -> {:error, errors}
    end
  end

  def cast!(data, schema) do
    case cast(data, schema) do
      {:ok, value} -> value
      _ -> raise "Tarams :: bad input data"
    end
  end

  @doc """
  Cast and validate params with given schema.
  """
  @spec cast(data :: map(), schema :: map()) ::
          %Tarams.Result{}
  def cast_only(data, schema) when is_map(data) do
    schema = schema |> Tarams.Schema.expand()

    Result.new(schema: schema, params: data)
    |> do_cast()
  end

  defp do_cast(%Result{} = result) do
    Enum.reduce(result.schema, result, fn field, acc ->
      case cast_field(acc.params, field) do
        {:ok, {field_name, value}} -> Result.put_data(acc, field_name, value)
        {:error, {field_name, error}} -> Result.put_error(acc, field_name, error)
      end
    end)
  end

  @doc """
  Validate params with given schema.
  """
  def validate(data, schema) when is_map(data) do
    schema = schema |> Tarams.Schema.expand()

    Result.new(schema: schema, params: data, valid_data: data)
    |> do_validate()
    |> case do
      %Result{valid?: true} -> :ok
      %{errors: errors} -> {:error, errors}
    end
  end

  defp do_validate(%Result{} = result) do
    Enum.reduce(result.schema, result, fn {field_name, _} = field, acc ->
      # skip if there is an error
      if Result.get_error(acc, field_name) do
        acc
      else
        case validate_field(acc.valid_data, field) do
          :ok -> acc
          {:error, {field_name, error}} -> Result.put_error(acc, field_name, error)
        end
      end
    end)
  end

  @doc """
  Transform params with given schema.
  """
  def transform(data, schema) do
    schema = schema |> Tarams.Schema.expand()

    Result.new(schema: schema, params: data, valid_data: data)
    |> do_transform()
    |> case do
      %Result{valid?: true, valid_data: valid_data} -> {:ok, valid_data}
      %{errors: errors} -> {:error, errors}
    end
  end

  defp do_transform(%Result{} = result) do
    Enum.reduce(result.schema, result, fn {field_name, _} = field, acc ->
      # skip if there is an error
      if Result.get_error(acc, field_name) do
        acc
      else
        case transform_field(acc.valid_data, field) do
          {:ok, {field_name, value}} -> Result.put_data(acc, field_name, value)
          {:error, {field_name, error}} -> Result.put_error(acc, field_name, error)
        end
      end
    end)
  end

  ## cast schema logic
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

  defp cast_value(nil, _), do: {:ok, nil}

  # cast array of custom map
  defp cast_value(value, {:array, %{} = type}) do
    cast_array(type, value)
  end

  # cast nested map
  defp cast_value(value, %{} = type) when is_map(value) do
    case cast_only(value, type) do
      %Result{valid?: true, valid_data: valid_data} ->
        {:ok, valid_data}

      %{errors: errors} ->
        {:error, errors}
    end
  end

  defp cast_value(_, %{}), do: :error

  defp cast_value(value, type) do
    Type.cast(type, value)
  end

  # rewrite cast_array for more detail errors
  def cast_array(type, value, acc \\ [])

  def cast_array(type, [value | t], acc) do
    case cast_value(value, type) do
      {:ok, data} ->
        cast_array(type, t, [data | acc])

      error ->
        error
    end
  end

  def cast_array(_, [], acc), do: {:ok, Enum.reverse(acc)}

  ## Validate schema
  defp validate_field(data, {field_name, definitions}) do
    value = get_value(data, field_name)
    # remote transform option from definition
    definitions
    |> Enum.map(fn validation ->
      do_validate(field_name, value, data, validation)
    end)
    |> collect_validation_result()
    |> case do
      {:error, errors} -> {:error, {field_name, errors}}
      :ok -> :ok
    end
  end

  # handle custom validation for required
  # Support dynamic require validation
  defp do_validate(_, value, data, {:required, required})
       when is_function(required) or is_tuple(required) do
    case apply_function(required, value, data) do
      {:error, _} = error ->
        error

      rs ->
        is_required = rs not in [false, nil]
        Valdi.validate(value, [{:required, is_required}])
    end
  end

  defp do_validate(_, value, _data, {:required, required}) do
    Valdi.validate(value, [{:required, required}])
  end

  # skip validation for nil
  defp do_validate(_, nil, _, _), do: :ok

  # validate type
  defp do_validate(_, value, _, {:type, type}) when is_map(type) do
    # validate nested map
    if is_map(value) do
      validate(value, type)
    else
      {:error, "is invalid"}
    end
  end

  defp do_validate(_, value, _, {:type, {:array, type}}) when is_map(type) do
    Enum.map(value, fn item ->
      do_validate(nil, item, value, {:type, type})
    end)
    |> collect_validation_result()
  end

  # validate module
  defp do_validate(_, value, _, {:type, type}) do
    if is_struct(type) and Kernel.function_exported?(type, :validate, 1) do
      type.validate(value)
    else
      Valdi.validate(value, [{:type, type}])
    end
  end

  # support custom validate fuction with whole data
  defp do_validate(field_name, value, data, {:func, func}) do
    case func do
      {mod, func} -> apply(mod, func, [value, data])
      {mod, func, args} -> apply(mod, func, args ++ [value, data])
      func when is_function(func, 3) -> func.(field_name, value, data)
      func when is_function(func) -> func.(value)
      _ -> {:error, "invalid custom validation function"}
    end
  end

  defp do_validate(_, value, _, validator) do
    Valdi.validate(value, [validator])
  end

  defp collect_validation_result(results) do
    summary =
      Enum.reduce(results, {:ok, []}, fn
        :ok, acc -> acc
        {:error, msg}, {_, acc_msg} when is_list(msg) -> {:error, [msg | acc_msg]}
        {:error, msg}, {_, acc_msg} -> {:error, [[msg] | acc_msg]}
      end)

    case summary do
      {:ok, _} ->
        :ok

      {:error, errors} ->
        {:error, Enum.concat(errors)}
    end
  end

  ## Transform schema
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
end
