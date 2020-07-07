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

  @doc """
  Parse and validate input params with predefined schema
  """
  @spec parse(map, map) :: {:ok, map} | {:error, Ecto.Changeset.t()}
  def parse(schema, params) do
    default = get_default(schema)
    types = get_type(schema)
    validator = get_validator(schema)
    required_field = get_required_fields(schema)

    changeset =
      cast({default, types}, params, Map.keys(types))
      |> validate_required(required_field)

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
end
