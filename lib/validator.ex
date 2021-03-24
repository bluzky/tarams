defmodule Tarams.Validator do
  def validate(changeset, validations) do
    Enum.reduce(validations, changeset, fn {field, rules}, cs ->
      validate_rule(cs, field, rules)
    end)
  end

  defp validate_rule(changeset, field, rules) when is_list(rules) do
    Enum.reduce(rules, changeset, fn rule, acc ->
      validate_rule(acc, field, rule)
    end)
  end

  defp validate_rule(changeset, field, func) when is_function(func) do
    validate_rule(changeset, field, {func, []})
  end

  defp validate_rule(changeset, field, {func, opts}) when is_function(func) do
    apply(func, [changeset, field, opts])
  end

  defp validate_rule(changeset, field, {val_type, opts}) do
    apply(Ecto.Changeset, :"validate_#{val_type}", [changeset, field, opts])
  end
end
