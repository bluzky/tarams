defmodule TaramsVaidatorTest do
  use ExUnit.Case

  test "test validate params with invalid value should fail" do
    schema = %{
      page: [type: :integer, validate: {:number, [greater_than: 0]}]
    }

    params = %{
      "page" => "-1"
    }

    {rs, _} = Tarams.parse(schema, params)
    assert rs == :error
  end

  test "test not existing field should pass validation" do
    schema = %{
      page: [type: :integer, validate: {:number, [greater_than: 0]}]
    }

    params = %{}

    {rs, _} = Tarams.parse(schema, params)
    assert rs == :ok
  end

  test "test validate params with list validator should pass" do
    schema = %{
      page: [type: :integer, validate: [{:number, [greater_than: 0]}]]
    }

    params = %{
      "page" => "-1"
    }

    assert %{valid?: false} = Tarams.cast(schema, params)
  end

  test "test validate params with list custom validator should pass" do
    schema = %{
      page: [
        type: :integer,
        validate: fn cs, field, _opts ->
          val = Ecto.Changeset.get_change(cs, field)

          if val > 0 do
            cs
          else
            Ecto.Changeset.add_error(cs, field, "can not be negative")
          end
        end
      ]
    }

    params = %{
      "page" => "-1"
    }

    assert %{valid?: false} = Tarams.cast(schema, params)
  end
end
