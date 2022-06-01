defmodule Tarams.UtilsTest do
  use ExUnit.Case
  alias Tarams.Utils

  defmodule Address do
    defstruct [:province, :city]
  end

  describe "test srub_params" do
    test "scrub empty string to nil" do
      params = %{"email" => "", "type" => "customer"}
      assert %{"email" => nil, "type" => "customer"} = Utils.scrub_param(params)
      assert %{"email" => nil, "type" => "customer"} = Tarams.scrub_param(params)
    end

    test "scrub string with all space to nil" do
      params = %{"email" => "   ", "type" => "customer"}
      assert %{"email" => nil, "type" => "customer"} = Utils.scrub_param(params)
    end

    test "scrub success with atom key" do
      params = %{email: "   ", password: "123"}
      assert %{email: nil, password: "123"} = Utils.scrub_param(params)
    end

    test "scrub success with nested map" do
      params = %{
        email: "   ",
        password: "123",
        address: %{street: "", province: "   ", city: "HCM"}
      }

      assert %{address: %{street: nil, province: nil, city: "HCM"}} = Utils.scrub_param(params)
    end

    test "scrub array params" do
      params = %{ids: [1, 2, "3", "", "  "]}
      assert %{ids: [1, 2, "3", nil, nil]} = Utils.scrub_param(params)
    end

    test "scrub success with mix atom and string key" do
      params = %{email: "   "} |> Map.put("type", "customer")
      assert %{email: nil} = Utils.scrub_param(params)
    end

    test "scrub skip struct" do
      params = %{
        "email" => "   ",
        "type" => "customer",
        "address" => %Address{province: "   ", city: "Hochiminh"}
      }

      assert %{"address" => %Address{province: "   ", city: "Hochiminh"}} =
               Utils.scrub_param(params)
    end

    test "scrub plug" do
      params = %{email: "   ", password: "123"}
      assert %{params: %{email: nil, password: "123"}} = Utils.plug_scrub(%{params: params})
      assert %{params: %{email: nil, password: "123"}} = Tarams.plug_scrub(%{params: params})
      assert %{params: %{email: nil}} = Utils.plug_scrub(%{params: params}, [:email, :name])
    end
  end

  describe "test clean_nil" do
    test "clean nil map" do
      params = %{"email" => nil, "type" => "customer"}
      assert %{"type" => "customer"} = Utils.clean_nil(params)
      assert %{"type" => "customer"} = Tarams.clean_nil(params)
    end

    test "scrub nil success with list" do
      params = %{ids: [2, nil, 3, nil]}
      assert %{ids: [2, 3]} = Utils.clean_nil(params)
    end

    test "clean nil success with nested map" do
      params = %{
        email: nil,
        password: "123",
        address: %{street: nil, province: nil, city: "HCM"}
      }

      assert %{address: %{city: "HCM"}} = Utils.clean_nil(params)
    end

    test "clean nil success with nested  list" do
      params = %{
        users: [
          %{
            name: nil,
            age: 20,
            hobbies: ["cooking", nil]
          },
          nil
        ]
      }

      assert %{
               users: [
                 %{
                   age: 20,
                   hobbies: ["cooking"]
                 }
               ]
             } == Utils.clean_nil(params)
    end

    test "clean nil skip struct" do
      params = %{
        "email" => "dn@gmail.com",
        "type" => "customer",
        "address" => %Address{province: nil, city: "Hochiminh"}
      }

      assert %{"address" => %Address{province: nil, city: "Hochiminh"}} = Utils.clean_nil(params)
    end
  end
end
