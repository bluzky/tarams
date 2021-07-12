defmodule Tarams do
  @moduledoc """
  `Tarams` provide a simpler way to define and validate data with power of `Ecto.Changeset` and schemaless. And `Tarams` is even more powerful with:
  - default function which generate value each casting time
  - custom validation functions
  - custom parse functions
  - shorter schema definition

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

  - `validate` define how a field is validated, read section **Validation** for more details.

  - `default` set default value. It could be a value or a function, if is is a function, it will be evaluated each time `parse` or `cast` function is called.

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



  ### Validation

  - You can use any validation which `Ecto.Changeset` supports. There is a simple rule to map schema declaration with `Ecto.Changeset` validation function. Simply concatenate `validate` and validation type to get `Ecto.Changeset` validation function.

  ```elixir
  validate: {<validation_name>, <validation_option>}
  ```

  **Example**

  ```elixir
    %{status: [type: string, validate: {:inclusion, ["open", "pending"]}]}

    # is translated to
    Ecto.Changeset.validate_inclustion(changeset, :status, ["open", "pending"])
  ```

  - If your need many validate function, just pass a list to `:validate` option.
  **Example**

  ```elixir
    %{status: [type: string, validate: [{validate1, otps1}, {validate2, opts2}]] }
  ```

  - You can pass a custom validation function too. Your function must follow this spec

  `fn(Ecto.Changeset, atom, list) :: Ecto.Changeset `

  **Example**

  ```elixir
    def custom_validate(changeset, field_name, opts) do
        # your validation logic
    end
    %{status: [type: :string, validate: {&custom_validate/2, <your_options>}]}
  ```
  """

  import Ecto.Changeset, except: [apply_changes: 1]
  alias Ecto.Changeset

  @doc """
  Cast params to a changeset and then check if `changeset.valid? = true` then invoke `Changeset.apply_changes` and return `{:ok, data}`. Otherwise, return `{:error, changeset}`
  """
  @spec parse(map, map) :: {:ok, map} | {:error, Ecto.Changeset.t()}
  def parse(schema, params) do
    case cast(schema, params) do
      %{valid?: true} = changeset ->
        {:ok, apply_changes(changeset)}

      changeset ->
        {:error, changeset}
    end
  end

  @doc """
  Build an Ecto schemaless schema and then do casting and validating params
  """
  @spec cast(map, map) :: Ecto.Changeset
  def cast(schema, params) do
    %{
      types: types,
      default: default,
      validators: validation_rules,
      required_fields: required_fields,
      custom_cast_funcs: custom_cast_funcs,
      embedded_fields: embedded_fields
    } = Tarams.SchemaParser.parse(schema)

    default_cast_fields =
      types
      |> Map.keys()
      |> Kernel.--(Map.keys(custom_cast_funcs))
      |> Kernel.--(Map.keys(embedded_fields))

    cast({default, types}, params, default_cast_fields)
    |> cast_custom_fields(custom_cast_funcs, params)
    |> cast_embedded_fields(embedded_fields)
    |> validate_required(required_fields)
    |> Tarams.Validator.validate(validation_rules)
  end

  def apply_changes(%Changeset{} = changeset) do
    Enum.reduce(changeset.changes, changeset.data, fn {key, value}, acc ->
      value =
        case value do
          %Ecto.Changeset{} ->
            apply_changes(value)

          value when is_list(value) ->
            apply_changes(value)

          _ ->
            value
        end

      Map.put(acc, key, value || acc[key])
    end)
  end

  def apply_changes(cs) when is_list(cs) do
    Enum.map(cs, &apply_changes(&1))
  end

  def apply_changes(cs), do: cs

  defp cast_custom_fields(%Changeset{} = changeset, custom_cast_fields, params) do
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

  # cast nested schema
  defp cast_embedded_fields(%Changeset{} = changeset, embedded_fields) do
    Enum.reduce(embedded_fields, changeset, fn {field_name, opts}, acc ->
      cast_embedded_field(acc, field_name, opts[:type])
    end)
  end

  # cast many
  defp cast_embedded_field(%Changeset{} = changeset, field, {:array, schema}) do
    params = Map.get(changeset.params, field) || Map.get(changeset.params, "#{field}")

    case params do
      nil ->
        put_embed_changes(changeset, field, nil)

      params when is_list(params) ->
        embedded_cs = Enum.map(params, &cast(schema, &1))
        valid? = Enum.reduce(embedded_cs, true, fn cs, acc -> acc and cs.valid? end)

        changeset
        |> put_embed_changes(field, embedded_cs)
        |> Map.put(:valid?, valid? and changeset.valid?)

      _ ->
        add_error(changeset, field, "is invalid")
    end
  end

  # cast one 
  defp cast_embedded_field(%Changeset{} = changeset, field, %{} = schema) do
    params = Map.get(changeset.params, field) || Map.get(changeset.params, "#{field}")

    case params do
      nil ->
        put_embed_changes(changeset, field, nil)

      params when is_map(params) ->
        embedded_cs = cast(schema, params)

        changeset
        |> put_embed_changes(field, embedded_cs)
        |> Map.put(:valid?, embedded_cs.valid? and changeset.valid?)

      _ ->
        add_error(changeset, field, "is invalid")
    end
  end

  defp put_embed_changes(changeset, field, changes) do
    changes = Map.put(changeset.changes, field, changes)

    %{changeset | changes: changes}
  end
end
