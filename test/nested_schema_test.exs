defmodule NestedSchemaTest do
  use ExUnit.Case
  doctest Tarams

  describe "Nested schema" do
    @map_schema %{
      item: %{
        name: [type: :string, required: true],
        sku: [type: :string, required: true],
        photo: [type: :string]
      }
    }
    test "nested schema should success" do
      data1 = %{
        "item" => %{
          "name" => "product 1",
          "sku" => "sku1",
          "photo" => ""
        }
      }

      changeset = Tarams.cast(@map_schema, data1)
      assert changeset.valid?

      assert %{
               item: %{
                 name: "product 1",
                 sku: "sku1",
                 photo: nil
               }
             } = Tarams.apply_changes(changeset)
    end

    test "nested schema invalid value should be invalid" do
      data1 = %{
        "item" => %{
          "name" => "product 1",
          "photo" => ""
        }
      }

      changeset = Tarams.cast(@map_schema, data1)
      assert not changeset.valid?

      assert %{
               changes: %{
                 item: %{
                   errors: [sku: {"can't be blank", [validation: :required]}]
                 }
               }
             } = changeset
    end

    test "nested schema cast on nil should be nil" do
      data1 = %{}

      changeset = Tarams.cast(@map_schema, data1)
      assert changeset.valid?

      assert %{
               changes: %{
                 item: nil
               }
             } = changeset
    end

    test "nested schema cast on nil with required should be invalid" do
      map_schema = %{
        item: [
          type: %{
            name: [type: :string, required: true]
          },
          required: true
        ]
      }

      data1 = %{}

      changeset = Tarams.cast(map_schema, data1)

      assert not changeset.valid?
      assert %{errors: [item: {"can't be blank", [validation: :required]}]} = changeset
    end
  end

  describe "Nested list schema" do
    @list_schema %{
      items:
        {:array,
         %{
           sku: [type: :string, required: true]
         }}
    }
    test "Cast list schema should success" do
      data = %{
        items: [%{sku: "1"}, %{sku: "2"}]
      }

      cs = Tarams.cast(@list_schema, data)
      assert cs.valid?

      assert %{
               items: [%{sku: "1"}, %{sku: "2"}]
             } = Tarams.apply_changes(cs)
    end

    test "Cast list schema bad value should invalid" do
      data = %{
        items: [%{}, %{sku: "2"}]
      }

      cs = Tarams.cast(@list_schema, data)

      assert not cs.valid?

      assert [%{errors: [sku: {"can't be blank", [validation: :required]}]} | _] =
               cs.changes.items
    end

    test "cast list nil should return nil" do
      data = %{}

      cs = Tarams.cast(@list_schema, data)

      assert cs.valid?
      assert cs.changes.items == nil
    end

    test "cast list with default" do
      list_schema = %{
        items: [
          type:
            {:array,
             %{
               sku: [type: :string, required: true]
             }},
          default: [%{sku: "1"}]
        ]
      }

      data = %{}

      cs = Tarams.cast(list_schema, data)

      assert cs.valid?
      assert %{items: [%{sku: "1"}]} = Tarams.apply_changes(cs)
    end
  end
end
