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

  **Example**
  ```elixir
    %{status: [type: string, validate: {:inclusion, ["open", "pending"]}]}

    # is translated to
    Ecto.Changeset.validate_inclustion(changeset, :status, ["open", "pending"])
  ```

  - `default`: set default value. It could be a value or a function, if is is a function, it will be evaluated each time `parse` function is called.

  **Example**
  ```elixir
    %{
      category: [type: :string, default: "elixir"],
      end_date: [type: :date, default: &Timex.today/1]
    }
  ```

  - `cast_func`: custom function to cast raw value to schema type. This is `cast_func` spec `fn(any) :: {:ok, any} | {:error, binary} `
  By defaut, `parse` function uses `Ecto.Changeset` cast function for built-in types, with `cast_func` you can define your own cast function for your custom type.
  **Example**
  ```elixir
  schema =
    %{
      status: [type: {:array, :string}, cast_func: fn value -> {:ok, String.split(",")} end]
    }
  Tarams.parse(schema, %{status: "processing,dropped"})
  ```
  """

  import Ecto.Changeset
  alias Ecto.Changeset

  @doc """
  Parse and validate input params with predefined schema
  """
  @spec parse(map, map) :: {:ok, map} | {:error, Ecto.Changeset.t()}
  def parse(schema, params) do
    %{
      types: types,
      default: default,
      validators: validators,
      required_fields: required_fields,
      custom_cast_funcs: custom_cast_funcs
    } = Tarams.SchemaParser.parse(schema)

    default_cast_fields =
      types
      |> Map.keys()
      |> Enum.filter(&(&1 not in Map.keys(custom_cast_funcs)))

    IO.inspect(default)

    changeset =
      cast({default, types}, params, default_cast_fields)
      |> IO.inspect()
      |> cast_custom_fields(custom_cast_funcs, params)
      |> validate_required(required_fields)

    changeset =
      Enum.reduce(validators, changeset, fn {field, {val_type, val_opts}}, cs ->
        apply(Ecto.Changeset, :"validate_#{val_type}", [cs, field, val_opts])
      end)

    if changeset.valid? do
      {:ok, apply_changes(changeset)}
    else
      {:error, changeset}
    end
  end

  @doc """
  cast fields with custom cast function
  """
  def cast_custom_fields(%Changeset{} = changeset, custom_cast_fields, params) do
    Enum.reduce(custom_cast_fields, changeset, fn {field, opts}, changeset ->
      # params can be map with atom key or binary key
      value = Map.get(params, field) || Map.get(params, "#{field}")

      if is_nil(value) do
        changeset
      else
        cast_func = Keyword.get(opts, :cast_func)

        case cast_func.(value) do
          {:ok, casted_value} ->
            put_change(changeset, field, casted_value)

          {:error, message} ->
            add_error(changeset, field, message)
        end
      end
    end)
  end
end
