defmodule TaramsTest do
  use ExUnit.Case
  doctest Tarams

  test "test short form and long form should pass" do
    schema = %{
      keyword: :string,
      page: [type: :integer]
    }

    params = %{}

    {st, data} = Tarams.parse(schema, params)
    assert st == :ok
  end

  test "test parse params to proper data type should pass" do
    schema = %{
      keyword: :string,
      page: :integer,
      date: :date
    }

    params = %{
      "keyword" => "hello",
      "page" => "1",
      "date" => "2020-10-21"
    }

    {rs, data} = Tarams.parse(schema, params)

    assert rs == :ok
    assert data.page == 1
    assert data.date == ~D[2020-10-21]
  end

  test "test params with atom key should pass" do
    schema = %{
      keyword: :string,
      page: :integer,
      date: :date
    }

    params = %{
      keyword: "hello",
      page: "1",
      date: "2020-10-21"
    }

    {rs, data} = Tarams.parse(schema, params)

    assert rs == :ok
    assert data.page == 1
    assert data.date == ~D[2020-10-21]
  end

  test "test required field not exist should fail" do
    schema = %{
      status: [type: :string, required: true]
    }

    params = %{}

    {rs, _} = Tarams.parse(schema, params)
    assert rs == :error
  end

  test "test required field with valid value should pass" do
    schema = %{
      status: [type: :string, required: true]
    }

    params = %{"status" => "success"}

    {rs, _} = Tarams.parse(schema, params)
    assert rs == :ok
  end

  test "test default value should pass" do
    schema = %{
      status: [type: :string, default: "open"]
    }

    params = %{}

    {rs, data} = Tarams.parse(schema, params)
    assert rs == :ok
    assert data.status == "open"
  end

  test "test default value with function should pass" do
    default_fn = fn -> "done" end

    schema = %{
      status: [type: :string, default: default_fn]
    }

    params = %{}

    {rs, data} = Tarams.parse(schema, params)
    assert rs == :ok
    assert data.status == "done"
  end

  test "test validate params with valid value should pass" do
    schema = %{
      status: [type: :string, validate: {:inclusion, ["open", "in_progress", "done"]}]
    }

    params = %{
      "status" => "open"
    }

    {rs, data} = Tarams.parse(schema, params)
    assert rs == :ok
    assert data.status == "open"
  end

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

  test "test custom cast field function success should pass" do
    schema = %{
      page: [
        type: {:array, :integer},
        cast_func: fn v -> {:ok, String.split(v, ",") |> Enum.map(&String.to_integer(&1))} end
      ]
    }

    params = %{page: "1,2,3"}

    {rs, data} = Tarams.parse(schema, params)
    assert rs == :ok
    assert data.page == [1, 2, 3]
  end

  test "test custom cast field  function error should not pass" do
    schema = %{
      page: [
        type: :integer,
        cast_func: fn v -> {:error, "Not integer"} end
      ]
    }

    params = %{page: "1,2,3"}

    {rs, data} = Tarams.parse(schema, params)
    assert rs == :error
  end

  test "test custom cast field function with no params value should pass" do
    schema = %{
      page: [
        type: {:array, :integer},
        cast_func: fn v -> {:ok, String.split(v, ",") |> Enum.map(&String.to_integer(&1))} end
      ]
    }

    params = %{}

    {rs, data} = Tarams.parse(schema, params)
    assert rs == :ok
  end
end
