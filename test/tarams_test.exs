defmodule ParamTest.StringList do
  def cast(value) when is_binary(value) do
    rs =
      String.split(value, ",")
      |> Tarams.scrub_param()
      |> Tarams.clean_nil()

    {:ok, rs}
  end

  def cast(_), do: :error
end

defmodule ParamTest do
  use ExUnit.Case
  alias Tarams

  alias ParamTest.StringList

  describe "Tarams.cast" do
    @type_checks [
      [:string, "Bluz", "Bluz", :ok],
      [:string, 10, nil, :error],
      [:binary, "Bluz", "Bluz", :ok],
      [:binary, true, nil, :error],
      [:boolean, "1", true, :ok],
      [:boolean, "true", true, :ok],
      [:boolean, "0", false, :ok],
      [:boolean, "false", false, :ok],
      [:boolean, true, true, :ok],
      [:boolean, 10, nil, :error],
      [:integer, 10, 10, :ok],
      [:integer, "10", 10, :ok],
      [:integer, 10.0, nil, :error],
      [:integer, "10.0", nil, :error],
      [:float, 10.1, 10.1, :ok],
      [:float, "10.1", 10.1, :ok],
      [:float, 10, 10.0, :ok],
      [:float, "10", 10.0, :ok],
      [:float, "10xx", nil, :error],
      [:decimal, "10.1", Decimal.new("10.1"), :ok],
      [:decimal, 10, Decimal.new("10"), :ok],
      [:decimal, 10.1, Decimal.new("10.1"), :ok],
      [:decimal, Decimal.new("10.1"), Decimal.new("10.1"), :ok],
      [:decimal, "10.1a", nil, :error],
      [:decimal, :ok, nil, :error],
      [:map, %{name: "Bluz"}, %{name: "Bluz"}, :ok],
      [:map, %{"name" => "Bluz"}, %{"name" => "Bluz"}, :ok],
      [:map, [], nil, :error],
      [{:array, :integer}, [1, 2, 3], [1, 2, 3], :ok],
      [{:array, :integer}, ["1", "2", "3"], [1, 2, 3], :ok],
      [{:array, :string}, ["1", "2", "3"], ["1", "2", "3"], :ok],
      [StringList, "1,2,3", ["1", "2", "3"], :ok],
      [StringList, "", [], :ok],
      [StringList, [], nil, :error],
      [{:array, StringList}, ["1", "2"], [["1"], ["2"]], :ok],
      [{:array, StringList}, [1, 2], nil, :error],
      [:date, "2020-10-11", ~D[2020-10-11], :ok],
      [:date, "2020-10-11T01:01:01", ~D[2020-10-11], :ok],
      [:date, ~D[2020-10-11], ~D[2020-10-11], :ok],
      [:date, ~N[2020-10-11 01:00:00], ~D[2020-10-11], :ok],
      [:date, ~U[2020-10-11 01:00:00Z], ~D[2020-10-11], :ok],
      [:date, "2", nil, :error],
      [:time, "01:01:01", ~T[01:01:01], :ok],
      [:time, ~N[2020-10-11 01:01:01], ~T[01:01:01], :ok],
      [:time, ~U[2020-10-11 01:01:01Z], ~T[01:01:01], :ok],
      [:time, ~T[01:01:01], ~T[01:01:01], :ok],
      [:time, "2", nil, :error],
      [:naive_datetime, "-2020-10-11 01:01:01", ~N[-2020-10-11 01:01:01], :ok],
      [:naive_datetime, "2020-10-11 01:01:01", ~N[2020-10-11 01:01:01], :ok],
      [:naive_datetime, "2020-10-11 01:01:01+07", ~N[2020-10-11 01:01:01], :ok],
      [:naive_datetime, ~N[2020-10-11 01:01:01], ~N[2020-10-11 01:01:01], :ok],
      [
        :naive_datetime,
        %{year: 2020, month: 10, day: 11, hour: 1, minute: 1, second: 1},
        ~N[2020-10-11 01:01:01],
        :ok
      ],
      [
        :naive_datetime,
        %{year: "", month: 10, day: 11, hour: 1, minute: 1, second: 1},
        nil,
        :error
      ],
      [
        :naive_datetime,
        %{year: "", month: "", day: "", hour: "", minute: "", second: ""},
        nil,
        :ok
      ],
      [:naive_datetime, "2", nil, :error],
      [:naive_datetime, true, nil, :error],
      [:datetime, "-2020-10-11 01:01:01", ~U[-2020-10-11 01:01:01Z], :ok],
      [:datetime, "2020-10-11 01:01:01", ~U[2020-10-11 01:01:01Z], :ok],
      [:datetime, "2020-10-11 01:01:01-07", ~U[2020-10-11 08:01:01Z], :ok],
      [:datetime, ~N[2020-10-11 01:01:01], ~U[2020-10-11 01:01:01Z], :ok],
      [:datetime, ~U[2020-10-11 01:01:01Z], ~U[2020-10-11 01:01:01Z], :ok],
      [:datetime, "2", nil, :error],
      [:utc_datetime, "-2020-10-11 01:01:01", ~U[-2020-10-11 01:01:01Z], :ok],
      [:utc_datetime, "2020-10-11 01:01:01", ~U[2020-10-11 01:01:01Z], :ok],
      [:utc_datetime, "2020-10-11 01:01:01-07", ~U[2020-10-11 08:01:01Z], :ok],
      [:utc_datetime, ~N[2020-10-11 01:01:01], ~U[2020-10-11 01:01:01Z], :ok],
      [:utc_datetime, ~U[2020-10-11 01:01:01Z], ~U[2020-10-11 01:01:01Z], :ok],
      [:utc_datetime, "2", nil, :error],
      [:any, "any", "any", :ok]
    ]

    test "cast base type" do
      @type_checks
      |> Enum.each(fn [type, value, expected_value, expect] ->
        rs =
          Tarams.cast(%{"key" => value}, %{
            key: type
          })

        if expect == :ok do
          assert {:ok, %{key: ^expected_value}} = rs
        else
          assert {:error, _} = rs
        end
      end)
    end

    test "schema short hand" do
      assert {:ok, %{number: 10}} = Tarams.cast(%{number: "10"}, %{number: :integer})

      assert {:ok, %{number: 10}} =
               Tarams.cast(%{number: "10"}, %{number: [:integer, number: [min: 5]]})
    end

    test "cast ok" do
      assert 10 = Tarams.Type.cast!(:integer, 10)
      assert 10 = Tarams.Type.cast!(:integer, "10")
    end

    test "type cast raise exception" do
      assert_raise RuntimeError, fn ->
        Tarams.Type.cast!(:integer, "10xx")
      end
    end

    test "cast mixed keys atom and string" do
      assert {:ok, %{active: false, is_admin: true, name: "blue", age: 19}} =
               Tarams.cast(
                 %{"active" => false, "is_admin" => true, "name" => "blue", "age" => 19},
                 %{
                   active: :boolean,
                   is_admin: :boolean,
                   name: :string,
                   age: :integer
                 }
               )
    end

    test "Tarams.cast! success" do
      assert %{number: 10} = Tarams.cast!(%{number: "10"}, %{number: :integer})
    end

    test "Tarams.cast! raise exception" do
      assert_raise RuntimeError, fn ->
        Tarams.cast!(%{number: 10}, %{number: {:array, :string}})
      end
    end

    test "cast with alias" do
      schema = %{
        email: [type: :string, as: :user_email]
      }

      rs = Tarams.cast(%{email: "xx@yy.com"}, schema)
      assert {:ok, %{user_email: "xx@yy.com"}} = rs
    end

    test "cast with from" do
      schema = %{
        user_email: [type: :string, from: :email]
      }

      rs = Tarams.cast(%{email: "xx@yy.com"}, schema)
      assert {:ok, %{user_email: "xx@yy.com"}} = rs
    end

    test "cast use default value if field not exist in params" do
      assert {:ok, %{name: "Dzung"}} =
               Tarams.cast(%{}, %{name: [type: :string, default: "Dzung"]})
    end

    @tag :only
    test "cast use default function if field not exist in params" do
      assert {:ok, %{name: "123"}} =
               Tarams.cast(%{}, %{name: [type: :string, default: fn -> "123" end]})
    end

    test "cast func is used if set" do
      assert {:ok, %{name: "Dzung is so handsome"}} =
               Tarams.cast(%{name: "Dzung"}, %{
                 name: [
                   type: :string,
                   cast_func: fn value -> {:ok, "#{value} is so handsome"} end
                 ]
               })
    end

    test "cast func with 2 arguments" do
      assert {:ok, %{name: "DZUNG"}} =
               Tarams.cast(%{name: "Dzung", strong: true}, %{
                 name: [
                   type: :string,
                   cast_func: fn value, data ->
                     {:ok, (data.strong && String.upcase(value)) || value}
                   end
                 ]
               })
    end

    def upcase_string(value, _data) do
      {:ok, String.upcase(value)}
    end

    def upcase_string1(value) do
      {:ok, String.upcase(value)}
    end

    test "cast func with tuple module & function" do
      assert {:ok, %{name: "DZUNG"}} =
               Tarams.cast(%{name: "Dzung"}, %{
                 name: [
                   type: :string,
                   cast_func: {__MODULE__, :upcase_string}
                 ]
               })
    end

    test "cast func with 3 arguments return error" do
      assert {:error, %{name: ["bad function"]}} =
               Tarams.cast(%{name: "Dzung", strong: true}, %{
                 name: [
                   type: :string,
                   cast_func: fn value, _data, _name ->
                     {:ok, value}
                   end
                 ]
               })
    end

    test "cast func return custom message" do
      assert {:error, %{name: ["custom error"]}} =
               Tarams.cast(%{name: "Dzung"}, %{
                 name: [
                   type: :string,
                   cast_func: fn _ ->
                     {:error, "custom error"}
                   end
                 ]
               })
    end

    @schema %{
      user: [
        type: %{
          name: [type: :string, required: true],
          email: [type: :string, length: [min: 5]],
          age: [type: :integer]
        }
      ]
    }

    test "cast embed type with valid value" do
      data = %{
        user: %{
          name: "D",
          email: "d@h.com",
          age: 10
        }
      }

      assert {:ok, ^data} = Tarams.cast(data, @schema)
    end

    test "cast with no value should default to nil and skip validation" do
      data = %{
        user: %{
          name: "D",
          age: 10
        }
      }

      assert {:ok, %{user: %{email: nil}}} = Tarams.cast(data, @schema)
    end

    test "cast embed validation invalid should error" do
      data = %{
        user: %{
          name: "D",
          email: "h",
          age: 10
        }
      }

      assert {:error, %{user: %{email: ["length must be greater than or equal to 5"]}}} =
               Tarams.cast(data, @schema)
    end

    test "cast empty embed type should error" do
      data = %{
        user: ""
      }

      assert {:error, %{user: %{name: ["is required"]}}} = Tarams.cast(data, @schema)
    end

    test "cast empty map embed type should error" do
      data = %{
        user: %{}
      }

      assert {:error, %{user: %{name: ["is required"]}}} = Tarams.cast(data, @schema)
    end

    test "cast nil embed type should error" do
      data = %{
        user: nil
      }

      assert {:error, %{user: %{name: ["is required"]}}} = Tarams.cast(data, @schema)
    end

    @tag :only
    test "cast missing required value should error" do
      data = %{
        user: %{
          age: 10
        }
      }

      assert {:error, %{user: %{name: ["is required"]}}} = Tarams.cast(data, @schema)
    end

    @array_schema %{
      user: [
        type:
          {:array,
           %{
             name: [type: :string, required: true],
             email: [type: :string],
             age: [type: :integer]
           }}
      ]
    }
    test "cast array embed schema with valid data" do
      data = %{
        "user" => [
          %{
            "name" => "D",
            "email" => "d@h.com",
            "age" => 10
          }
        ]
      }

      assert {:ok, %{user: [%{age: 10, email: "d@h.com", name: "D"}]}} =
               Tarams.cast(data, @array_schema)
    end

    test "cast empty array embed should ok" do
      data = %{
        "user" => []
      }

      assert {:ok, %{user: []}} = Tarams.cast(data, @array_schema)
    end

    test "cast nil array embed should ok" do
      data = %{
        "user" => nil
      }

      assert {:ok, %{user: nil}} = Tarams.cast(data, @array_schema)
    end

    test "cast array embed with invalid value should error" do
      data = %{
        "user" => [
          %{
            "email" => "d@h.com",
            "age" => 10
          },
          %{
            "name" => "HUH",
            "email" => "om",
            "age" => 10
          }
        ]
      }

      assert {:error, %{user: %{name: ["is required"]}}} = Tarams.cast(data, @array_schema)
    end

    test "error with custom message" do
      schema = %{
        age: [type: :integer, number: [min: 10], message: "so khong hop le"]
      }

      assert {:error, %{age: ["so khong hop le"]}} = Tarams.cast(%{"age" => "abc"}, schema)
    end

    test "cast validate required skip if default is set" do
      assert {:ok, %{name: "Dzung"}} =
               Tarams.cast(%{}, %{name: [type: :string, default: "Dzung", required: true]})
    end

    test "validate array item" do
      assert {:ok, %{id: [1, 2, 3]}} =
               Tarams.cast(%{id: ["1", "2", 3]}, %{
                 id: [type: {:array, :integer}, each: [number: [min: 0]]]
               })
    end

    test "validate array item with error" do
      assert {:error, %{id: [[0, "must be greater than or equal to 2"]]}} =
               Tarams.cast(%{id: ["1", "2", 3]}, %{
                 id: [type: {:array, :integer}, each: [number: [min: 2]]]
               })
    end

    test "dynamic require validation" do
      assert {:ok, %{name: "Dzung"}} =
               Tarams.cast(%{}, %{
                 name: [type: :string, default: "Dzung", required: fn _, _ -> true end]
               })

      assert {:error, %{image: ["is required"]}} =
               Tarams.cast(%{}, %{
                 name: [type: :string, default: "Dzung", required: true],
                 image: [type: :string, required: fn _, data -> data.name == "Dzung" end]
               })

      assert {:error, %{image: ["is required"]}} =
               Tarams.cast(%{}, %{
                 name: [type: :string, default: "Dzung", required: true],
                 image: [type: :string, required: {__MODULE__, :should_require_image}]
               })

      assert {:error, %{image: ["is required"]}} =
               Tarams.cast(%{}, %{
                 name: [type: :string, default: "Dzung", required: true],
                 image: [type: :string, required: {__MODULE__, :should_require_image1}]
               })
    end

    def should_require_image1(_image) do
      true
    end

    def should_require_image(_image, data) do
      data.name == "Dzung"
    end
  end

  describe "test transform" do
    test "transform function no transform" do
      schema = %{
        status: [:integer, as: :product_status, into: nil]
      }

      data = %{status: 0, deleted: true}

      assert {:ok, %{product_status: 0}} = Tarams.cast(data, schema)
    end

    test "transform function accept value only" do
      convert_status = fn status ->
        text =
          case status do
            0 -> "draft"
            1 -> "published"
            2 -> "deleted"
          end

        {:ok, text}
      end

      schema = %{
        status: [:integer, as: :product_status, into: convert_status]
      }

      data = %{
        status: 0
      }

      assert {:ok, %{product_status: "draft"}} = Tarams.cast(data, schema)
    end

    @tag :only
    test "transform function with context" do
      convert_status = fn status, data ->
        text =
          case status do
            0 -> "draft"
            1 -> "published"
            2 -> "banned"
          end

        text = if data.deleted, do: "deleted", else: text

        {:ok, text}
      end

      schema = %{
        status: [:integer, as: :product_status, into: convert_status],
        deleted: :boolean
      }

      data = %{
        status: 0,
        deleted: true
      }

      assert {:ok, %{product_status: "deleted"}} = Tarams.cast(data, schema)
    end

    test "transform function with module, function tuple 2 arguments" do
      schema = %{
        status: [:string, as: :product_status, into: {__MODULE__, :upcase_string}]
      }

      data = %{status: "success"}

      assert {:ok, %{product_status: "SUCCESS"}} = Tarams.cast(data, schema)
    end

    test "transform function with module, function tuple 1 arguments" do
      schema = %{
        status: [:string, as: :product_status, into: {__MODULE__, :upcase_string1}]
      }

      data = %{status: "success"}

      assert {:ok, %{product_status: "SUCCESS"}} = Tarams.cast(data, schema)
    end

    test "transform function return value" do
      convert_status = fn status ->
        case status do
          0 -> "draft"
          1 -> "published"
          2 -> "deleted"
        end
      end

      schema = %{
        status: [:integer, as: :product_status, into: convert_status]
      }

      data = %{
        status: 0
      }

      assert {:ok, %{product_status: "draft"}} = Tarams.cast(data, schema)
    end
  end
end
