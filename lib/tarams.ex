defmodule Tarams do
  @moduledocs """

  """

  import Ecto.Changeset

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
