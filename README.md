# Tarams

Tarams provides a simple way for parsing request params with predefined schema

- [Installation](#installation)
- [Usage](#usage)
- [Set default value](#default-value)
- [Custom cast function](#custom-cast-function)
- [API Documentation](https://hexdocs.pm/tarams/)


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
    {:tarams, "~> 0.4.0"}
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
You can define a default value for a field if it's missing from the params.

```elixir
schema = %{
    status: [type: :string, default: "pending"]
}
```

Or you can define a default value as a function. This function is evaluated when `Tarams.parse` gets invoked.

```elixir
schema = %{
    date: [type: :utc_datetime, default: &Timex.now/0]
}
```

## Custom cast function
By default `Tarams` uses `Ecto.Changeset` to cast built-in types. If you don't want to use default casting functions, or you want define casting function for custom type, `tarams` provide `cast_func` option to define a custom cast function.
This is `cast_func` spec `fn(any) :: {:ok, any} | {:error, binary}`

If `cast_func` returns `{:ok, value}`, this value is added to changeset.
If it returns `{:error, message}`, error message is added to changeset errors.

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


## Validation

  - You can use any validation which `Ecto.Changeset` supports. There is a simple rule to map schema declaration with `Ecto.Changeset` validation function. Simply concatenate `validate` and validation type to get `Ecto.Changeset` validation function.

  ```elixir
  validate: {<validation_name>, <validation_option>}
  ```

  **Example**

  ```elixir
    %{status: [type: string, validate: {:inclusion, ["open", "pending"]}]}

    # is translated to
    Ecto.Changeset.validate_inclustion(changeset, :status, ["open", "pending"])
  ```

  - If your need many validate function, just pass a list to `:validate` option.
  **Example**

  ```elixir
    %{status: [type: string, validate: [{validate1, otps1}, {validate2, opts2}]] }
  ```

  - You can pass a custom validation function too. Your function must follow this spec

  `fn(Ecto.Changeset, atom, list) :: Ecto.Changeset `

  **Example**

  ```elixir
    def custom_validate(changeset, field_name, opts) do
        # your validation logic
    end
    %{status: [type: :string, validate: {&custom_validate/2, <your_options>}]}
  ```
  

## Contributors
If you find a bug or want to improve something, please send a pull request. Thank you!
