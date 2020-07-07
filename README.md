# Tarams

Tarams provides a simple way for parsing request params with predefined schema

~~~

- [Installation](#installation)
- [Usage](#usage)
- [API Documentation](https://hexdocs.pm/tarams/)

## Installation

[Available in Hex](https://hex.pm/tarams), the package can be installed
by adding `tarams` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:tarams, "~> 0.1.0"}
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

## Why Tarams

I looked for a library for parsing phoenix request params, and I found [params](https://github.com/vic/params). It is an awesome library but it does not support params validation.

I clone the source code and try to make some change to support validation but macro world is soo complicated. Then I decide to write my own library that support parsing and validating parameter and without macro ( after I red the book Metaprogramming in Elixir). So you can read the source code ( it is quite simple) and modify it to fit your need.


## Contributors
If you find a bug or want to improve something, please send a pull-request. Thank you!
