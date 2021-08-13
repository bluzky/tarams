# Tarams

Phoenix request params validation library.

[![Build Status](https://github.com/bluzky/tarams/workflows/Elixir%20CI/badge.svg)](https://github.com/bluzky/tarams/actions) [![Coverage Status](https://coveralls.io/repos/github/bluzky/tarams/badge.svg?branch=main)](https://coveralls.io/github/bluzky/tarams?branch=main) [![Hex Version](https://img.shields.io/hexpm/v/tarams.svg)](https://hex.pm/packages/tarams) [![docs](https://img.shields.io/badge/docs-hexpm-blue.svg)](https://hexdocs.pm/tarams/)



- [Why Tarams](#why-tarams)
- [Installation](#installation)
- [Usage](#usage)
- [Define schema](#define-schema)
    - [Default value](#default-value)
    - [Custom cast function](#custom-cast-function)
    - [Nested schema](#nested-schema)
- [Validation](#validation)
- [Contributors](#contributors)




## Why Tarams
    - Reduce code boilerplate 
    - Shorter schema definition
    - Default function which generate value each casting time
    - Custom validation functions
    - Custom parse functions
    
## Installation

[Available in Hex](https://hex.pm/tarams), the package can be installed
by adding `tarams` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:tarams, "~> 1.0.0"}
  ]
end
```

## Usage

```elixir
@index_params_schema  %{
    keyword: :string,
    status: [type: :string, required: true],
    group_id: [type: :integer, numer: [greater_than: 0]]
  }

def index(conn, params) do
    with {:ok, better_params} <- Tarams.cast(params, @index_params_schema) do
        # do anything with your params
    else
        {:error, errors} -> # return params error
    end
end
```


## Define schema

Schema is just a map and it can be nested. Each field is defined as

`<field_name>: [<field_spec>, ...]`

Or short form

`<field_name>: <type>`

Field specs is a keyword list thay may include:

- `type` is required, `Tarams` support same data type as `Ecto`. I borrowed code from Ecto
- `default`: default value or default function
- `cast_func`: custom cast function
- `number, format, length, in, not_in, func, required` are available validations


### Default value
You can define a default value for a field if it's missing from the params.

```elixir
schema = %{
    status: [type: :string, default: "pending"]
}
```

Or you can define a default value as a function. This function is evaluated when `Tarams.cast` gets invoked.

```elixir
schema = %{
    date: [type: :utc_datetime, default: &Timex.now/0]
}
```

### Custom cast function
You can define your own casting function, `tarams` provide `cast_func` option.
Your `cast_func` must follows this spec 

```elixir
fn(any) :: {:ok, any} | {:error, binary} | :error
```

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

Tarams.cast(%{user_id: "1,2,3"}, schema)
```
This is a demo parser function.

### Nested schema
With `Tarams` you can parse and validate nested map and list easily

```elixir
@my_schema %{
    status: :string,
    pagination: %{
        page: [type: :integer, number: [min: 1]],
        size: [type: :integer, number: [min: 10, max: 100"]]
    }
}
```

Or nested list schema

```elixir
@user_schema %{
    name: :string,
    email: [type: :string, required: true]
    addresses: [type: {:array, %{
        street: :string,
        district: :string,
        city: :string
    }}]
}
```


## Validation

`Tarams` uses `Valdi` validation library. You can read more about [Valdi here]()
Basically it supports following validation

- validate inclusion/exclusion
- validate length for string and enumerable types
- validate number
- validate string format/pattern
- validate custom function
- validate required(not nil) or not



  ```elixir
  product_schema = %{
    sku: [type: :string, required: true, length: [min: 6, max: 20]]
    name: [type: :string, required: true],
    quantity: [type: :integer, number: [min: 0]],
    type: [type: :string, in: ~w(physical digital)],
    expiration_date: [type: :naive_datetime, func: &my_validation_func/1]
  }
  ```
  

## Contributors
If you find a bug or want to improve something, please send a pull request. Thank you!
