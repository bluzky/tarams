defmodule Tarams do
  @moduledoc """
  Function for parsing and validating input params with predefined schema

  **Basic usage**
  ```elixir
    @index_params_schema  %{
      keyword: :string,
      status: [type: string, required: true],
      group_id: [type: :integer, validate: {:number, [greater_than: 0]}]
    }

    def index(conn, params) do
      with {:ok, better_params} <- Tarams.parse(@index_params_schema, params) do
        # do anything with your params
      else
        {:error, changset} -> # return params error
      end
    end

  ```

  A Schema is a simple map of `field: options`

  ### Sample schema
  ```elixir
    schema1 = %{
      keyword: :string
      status: [type: :string, required: true, validate: {:inclusion, ["open", "processing", "completed"]}],
      page: [type: :integer, default: 1],
      start_date: [type: :date, default: &Timex.today/0]
    }
  ```

  ### Field options

  - If there is no options, a field can be written in short form `<field_name>: <type>`.
  - `required` is false by default, this field is used to check if a field is required or not
  - `validate` define how a field is validated. You can use any validation which `Ecto.Changeset` supports. There is a simple rule to map schema declaration with `Ecto.Changeset` validation function.
  Simply concatenate `validate` and validation type to get `Ecto.Changeset` validation function.

  ### Example
  ```elixir
    %{status: [type: string, validate: {:inclusion, ["open", "pending"]}]}

    # is translated to
    Ecto.Changeset.validate_inclustion(changeset, :status, ["open", "pending"])
  ```

  - `default`: set default value. It could be a value or a function, if is is a function, it will be evaluated each time `parse` function is called.

  ### Example
  ```elixir
    %{
      category: [type: :string, default: "elixir"],
      end_date: [type: :date, default: &Timex.today/1]
    }
  ```

  """

  import Ecto.Changeset
  alias Ecto.Changeset

  @doc """
  Parse and validate input params with predefined schema
  """
  @spec parse(map, map) :: {:ok, map} | {:error, Ecto.Changeset.t()}
  def parse(schema, params) do
    default = get_default(schema)
    types = get_type(schema)
    validator = get_validator(schema)
    required_fields = get_required_fields(schema)

    custom_cast_fields = get_custom_cast_fields(schema)

    default_cast_fields =
      types
      |> Map.keys()
      |> Enum.filter(&(&1 not in Map.keys(custom_cast_fields)))

    changeset =
      cast({default, types}, params, default_cast_fields)
      |> cast_custom_fields(custom_cast_fields, params)
      |> validate_required(required_fields)

    changeset =
      Enum.reduce(validator, changeset, fn {field, {val_type, val_opts}}, cs ->
        apply(Ecto.Changeset, :"validate_#{val_type}", [cs, field, val_opts])
      end)

    if changeset.valid? do
      {:ok, apply_changes(changeset)}
    else
      {:error, changeset}
    end
  end

  @doc """
  Extract field default value, if default value is function, it is invoked
  """
  defp get_default(schema) do
    default =
      Enum.map(schema, fn
        {field, opts} when is_list(opts) ->
          if Keyword.has_key?(opts, :default) do
            default = Keyword.get(opts, :default)

            default =
              if is_function(default) do
                default.()
              else
                default
              end

            {field, default}
          else
            {field, nil}
          end

        {field, _type} ->
          {field, nil}
      end)

    Enum.into(default, %{})
  end

  @doc """
  Extract field type, support all ecto type
  """
  defp get_type(schema) do
    types =
      Enum.map(schema, fn
        {field, type} when is_atom(type) ->
          {field, type}

        {field, opts} when is_list(opts) ->
          if Keyword.has_key?(opts, :type) do
            {field, Keyword.get(opts, :type)}
          else
            raise "Type is missing"
          end

        {field, sub} when is_map(sub) ->
          raise "Nested is not supported yet"
      end)

    Enum.into(types, Map.new())
  end

  @doc """
  Extract field and validator for each field
  """
  defp get_validator(schema) do
    validators =
      Enum.map(schema, fn
        {field, opts} when is_list(opts) ->
          if Keyword.has_key?(opts, :validate) do
            {field, Keyword.get(opts, :validate)}
          else
            nil
          end

        _ ->
          nil
      end)

    Enum.filter(validators, &(not is_nil(&1)))
  end

  @doc """
  List required fields, field with option `required: true`, from schema
  """
  defp get_required_fields(schema) do
    Enum.filter(schema, fn
      {k, opts} when is_list(opts) ->
        Keyword.get(opts, :required) == true

      _ ->
        false
    end)
    |> Enum.map(&elem(&1, 0))
  end

  @doc """
   list field with custom cast function
  """
  defp get_custom_cast_fields(schema) do
    Enum.filter(schema, fn
      {_, opts} when is_list(opts) ->
        cast_func = Keyword.get(opts, :cast_func)

        cond do
          is_nil(cast_func) -> false
          is_function(cast_func) -> true
          true -> raise RuntimeError, ":cast_func must be a function"
        end

      _ ->
        false
    end)
    |> Enum.into(%{})
  end

  @doc """
  cast fields with custom cast function
  """
  def cast_custom_fields(%Changeset{} = changeset, custom_cast_fields, params) do
    default_values = get_default(custom_cast_fields)

    Enum.reduce(custom_cast_fields, changeset, fn {field, opts}, changeset ->
      # params can be map with atom key or binary key
      value = Map.get(params, field) || Map.get(params, "#{field}")

      if is_nil(value) do
        put_change(changeset, field, Map.get(default_values, field))
      else
        cast_func = Keyword.get(opts, :cast_func)

        case cast_func.(value) do
          {:ok, casted_value} -> put_change(changeset, field, casted_value)
          {:error, message} -> add_error(changeset, field, message)
        end
      end
    end)
  end
end
