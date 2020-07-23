# Tarams

Tarams provides a simple way for parsing request params with predefined schema



- [Installation](#installation)
- [Usage](#usage)
- [Set default value](#default-value)
- [Custom cast function](#custom-cast-function)
- [API Documentation](https://hexdocs.pm/tarams/)

## Installation

[Available in Hex](https://hex.pm/tarams), the package can be installed
by adding `tarams` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:tarams, "~> 0.2.0"}
  ]
end
```

## Usage

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

## Default value
You can define default value for a field if it is  missing in params
```elixir
schema = %{
    status: [type: :string, default: "pending"]
}
```

Or you can define default value as a function. This function is evaluated each time invoke `Tarams.parse`
```elixir
schema = %{
    date: [type: :utc_datetime, default: &Timex.now/0]
}
```

## Custom cast function
By default `Tarams` uses `Ecto.Changeset` to cast built-in types. If you don't want to use default casting functions, or you want define casting function for custom type, `tarams` provide `cast_func` option to define a custom cast function.
This is `cast_func` spec `fn(any) :: {:ok, any} | {:error, binary}`

If `cast_func` returns `{:ok, value}` this value is added to changeset
If it returns `{:error, message}`, error message is added to changeset errors

```elixir
def my_array_parser(value) do
    if is_binary(value) do
        ids = 
            String.split(value, ",")
            |> Enum.map(&String.to_integer(&1))
        
        {:ok, ids}
    else
        {:error, "Invalid string"
    end
end

schema = %{
    user_id: [type: {:array, :integer}, cast_func: &my_array_parser/1]
}

Tarams.parse(schema, %{user_id: "1,2,3"})
```
This is a demo parser function.

## Why Tarams

I looked for a library for parsing phoenix request params, and I found [params](https://github.com/vic/params). It is an awesome library but it does not support params validation.

I clone the source code and try to make some change to support validation but macro world is soo complicated. Then I decide to write my own library that support parsing and validating parameter and without macro ( after I red the book Metaprogramming in Elixir). So you can read the source code ( it is quite simple) and modify it to fit your need.


## Contributors
If you find a bug or want to improve something, please send a pull-request. Thank you!
