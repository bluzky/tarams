defmodule Tarams.Utils do
  @doc """
  A plug which do srubbing params

  **Use in Router**

      defmodule MyApp.Router do
        ...
        plug Tarams.plug_scrub
        ...
      end

  **Use in controller**

      plug Tarams.plug_scrub when action in [:index, :show]
      # or specify which field to scrub
      plug Tarams.plug_scrub, ["id", "keyword"] when action in [:index, :show]

  """
  def plug_scrub(conn, keys \\ []) do
    params =
      if keys == [] do
        scrub_param(conn.params)
      else
        Enum.reduce(keys, conn.params, fn key, params ->
          case Map.fetch(conn.params, key) do
            {:ok, value} -> Map.put(params, key, scrub_param(value))
            :error -> params
          end
        end)
      end

    %{conn | params: params}
  end

  @doc """
  Convert all parameter which value is empty string or string with all whitespace to nil. It works with nested map and list too.

  **Example**

      params = %{"keyword" => "   ", "email" => "", "type" => "customer"}
      Tarams.scrub_param(params)
      # => %{"keyword" => nil, "email" => nil, "type" => "customer"}

      params = %{user_ids: [1, 2, "", "  "]}
      Tarams.scrub_param(params)
      # => %{user_ids: [1, 2, nil, nil]}
  """
  def scrub_param(%{__struct__: mod} = struct) when is_atom(mod) do
    struct
  end

  def scrub_param(%{} = param) do
    Enum.reduce(param, %{}, fn {k, v}, acc ->
      Map.put(acc, k, scrub_param(v))
    end)
  end

  def scrub_param(param) when is_list(param) do
    Enum.map(param, &scrub_param/1)
  end

  def scrub_param(param) do
    if scrub?(param), do: nil, else: param
  end

  defp scrub?(" " <> rest), do: scrub?(rest)
  defp scrub?(""), do: true
  defp scrub?(_), do: false

  @doc """
  Clean all nil field from params, support nested map and list.

  **Example**

      params = %{"keyword" => nil, "email" => nil, "type" => "customer"}
      Tarams.clean_nil(params)
      # => %{"type" => "customer"}

      params = %{user_ids: [1, 2, nil]}
      Tarams.clean_nil(params)
      # => %{user_ids: [1, 2]}
  """
  @spec clean_nil(any) :: any
  def clean_nil(%{__struct__: mod} = param) when is_atom(mod) do
    param
  end

  def clean_nil(%{} = param) do
    Enum.reduce(param, %{}, fn {k, v}, acc ->
      if is_nil(v) do
        acc
      else
        Map.put(acc, k, clean_nil(v))
      end
    end)
  end

  def clean_nil(param) when is_list(param) do
    Enum.reduce(param, [], fn item, acc ->
      if is_nil(item) do
        acc
      else
        [clean_nil(item) | acc]
      end
    end)
    |> Enum.reverse()
  end

  def clean_nil(param), do: param
end
