# Cecil
[![Yard Documentation](https://img.shields.io/badge/rdoc.info-blue?label=docs)](https://www.rubydoc.info/github/nicholaides/cecil)
[![Gem Version](https://img.shields.io/gem/v/cecil)](https://rubygems.org/gems/cecil)

An experimental templating library designed specifically for generating source code (especially for languages that aren’t as meta-programmable as Ruby).

Cecil templates closely resemble the target source code, making templates easier to write, read, and maintain.

## Features

### Write templates in plain Ruby

Call `Cecil::Code.generate_string` and pass it a block. Inside the block, add lines of code via backticks (or use `src` if you prefer). Cecil returns your generated source code as a string.

#### Example

```ruby
model_code = Cecil::Code.generate_string do
  # Use backticks to add lines of code
  `import Model from '../model'`

  # Multi-line strings work, too.
  # Cecil preserves indentation.
  `class User extends Model {
    id: number
    name: string
    companyId: number | undefined
  }`

  # use #src if you prefer to avoid backticks
  src "export type Username = User['name']"
end

puts model_code
```

Returns:

```typescript
import Model from '../model'
class User extends Model {
  id: number
  name: string
  companyId: number | undefined
}
export type Username = User['name']
```

### Interpolate values with Cecil's low-noise syntax

Use `#[]` on the backticks to replace placeholders with actual values.

By default, placeholders start with `$` and are followed by an identifier.

Positional arguments match up with placeholders in order. Named arguments match placeholders by name.

#### Example

```ruby
field = "user"
types = ["string", "string[]"]
default_value = ["SilentHaiku", "DriftingSnowfall"]
field_class = "Model"

Cecil::Code.generate_string do
  # positional arguments match placeholders by position
  `let $field: $FieldType = $default`[field, types.join('|'), default_value.sort.to_json]

  # named arguments match placeholders by name
  `let $field: $FieldClass<$Types> = new $FieldClass($default)`[
    field: field,
    FieldClass: field_class,
    Types: types.join('|'),
    default: default_value.sort.to_json
  ]
end
```

Returns:

```typescript
let user: string|string[] = ["DriftingSnowfall","SilentHaiku"]
let user: Model<string|string[]> = new Model(["DriftingSnowfall","SilentHaiku"])
```


#### "Doesn't Ruby already have string interpolation?"

Yes, but compare the readability of these two approaches:

```ruby
`let $field: $FieldClass<$Types> = new $FieldClass($default)`[
  field: field,
  FieldClass: field_class,
  Types: types.join('|'),
  default: default_value.sort.to_json
]

# vs

field_types = types.join('|'),
default_json = default_value.sort.to_json
"let #{field}: #{field_class}<#{field_types}> = new #{field_class}(#{default_json})"
```

### Indents code blocks & closes brackets automatically

Pass a block to `#[]` gets indented and open brackets get closed automatically.

#### Example

```ruby
model = "User"
field_name = "name"
field_default = "Unnamed"

Cecil::Code.generate_string do
  `class $Class extends Model {`[model] do
    # indentation is preserved
    `id: number`

    `override get $field() {`[field_name] do
      `return super.$field ?? $defaultValue`[field_name, field_default.to_json]
    end
  end # the open bracket from `... Model {` gets closed with "}"
end
```

Returns:

```typescript
class User extends Model {
    id: number
    override get name() {
        return super.name ?? "Unnamed"
    }
}
```

### Emit source code to other locations

When generating source code, things like functions, parameters, classes, etc, often need to be declared, imported, or otherwise setup before being used.

`content_for` can be used to add content to a different location of your file.

Call `content_for(some_key) { ... }` with key and a block to store content under the key you provide. Call `content_for(some_key)` with the key and *no* block to insert your stored content at that location.

#### Example

```ruby
models = [
  { name: 'User', inherits: 'AuthModel' },
  { name: 'Company', inherits: 'Model' },
]

Cecil::Code.generate_string do
  # insert content collected for :imports
  content_for :imports

  models.each do |model|
    ``
    `class $Class extends $SuperClass {`[model[:name], model[:inherits]] do
      `id: number`
    end

    content_for :imports do
      # this gets inserted above
      `import $SuperClass from '../models/$SuperClass'`[SuperClass: model[:inherits]]
    end

    content_for :registrations do
      # this gets inserted below
      `$SuperClass.registerAncestor($Class)`[model[:inherits], model[:name]]
    end
  end

  ``
  # insert content collected for :registrations
  content_for :registrations
end
```

Returns:

```typescript
import AuthModel from '../models/AuthModel'
import Model from '../models/Model'

class User extends AuthModel {
    id: number
}

class Company extends Model {
    id: number
}

AuthModel.registerAncestor(User)
Model.registerAncestor(Company)
```

### Collect data as you go then use it earlier in the document

The `#defer` method takes a block and waits to call it until the rest of the template is evaluated. The block's result is inserted at the location where `#defer` was called.

This gives a similar ability to `#content_for`, but is more flexible because you can collect any kind of data, not just source code.

#### Example

```ruby
models = [
  { name: 'User', inherits: 'AuthModel' },
  { name: 'Company', inherits: 'Model' },
  { name: 'Candidate', inherits: 'AuthModel' },
]

Cecil::Code.generate_string do
  superclasses = []

  defer do
    # This block gets called after the rest of the parent block is finished.
    #
    # By the time this block is called, the `superclasses` array is full of data
    #
    # Even though this block is called later, the output is added at the location where `defer` was called
    `import { $SuperClasses } from '../models'`[superclasses.uniq.sort.join(', ')]
    ``
  end

  models.each do |model|
    superclasses << model[:inherits] # add more strings to `superclasses`, which is used in the block above

    `class $Class extends $SuperClass {}`[model[:name], model[:inherits]]
  end
end
```

Returns:

```typescript
import { AuthModel, Model } from '../models'

class User extends AuthModel {}
class Company extends Model {}
class Candidate extends AuthModel {}
```

### Customizable syntax and behaviors

Easily customize the following features to make Cecil suit your needs/preferences:

- placeholder syntax
- auto-closing brackets
- indentation

Customizations are performed by subclassing [`Cecil::Code`][{Code}] and overriding the relevant methods.

For example, Cecil comes with [`Cecil::Lang::TypeScript`][{Lang::TypeScript}] that you can use instead of of `Cecil::Code`. It has a few JavaScript/TypeScript-specific customizations. It's a subclass of `Cecil::Code` so it can be used the same way:

```ruby
Cecil::Lang::TypeScript.generate_string do
  # ...
end
```

## Use cases

Things I've personally used Cecil to generate:

- **serialization/deserialization code** generated from from specs (e.g. OpenAPI)
- **diagrams** (e.g. Mermaid, PlantUML, Dot/Graphviz)
    - ERDs/schemas
    - state machine diagrams
    - graphs
    - data visualizations
- **state machines** generated from a list of states and transitions
- **test cases** generated from data that describes inputs/setup and expected outputs; because parameterized tests can be very hard to debug
- **complex types** because meta-programming in TypeScript can get complex quickly

## Quick Reference

Reference documentation is on RubyDoc.info:
  [gem](https://www.rubydoc.info/gems/cecil)
  |
  [repo](https://www.rubydoc.info/github/nicholaides/cecil/main)

### Calling Cecil

Call
  [`Cecil::Code.generate`][{Code.generate}] /
  [`generate_string`][{Code.generate_string}]
  with a block and inside the block, use backticks or `#src` to emit lines of source code.
  E.g.

```ruby
# returns a string
Cecil::Code.generate_string do
  `function greet() {}`
  `function respond() {}`
end

# outputs to $stdout
Cecil::Code.generate do
  `function greet() {}`
  `function respond() {}`
end
```

See: [Methods available inside a Cecil block][{BlockContext}]

### Emitting source code

- [backticks/``` #`` ```/`#src`][{BlockContext#src}] emit source code.
  E.g.:
    ```ruby
    Cecil::Code.generate_string do
      `function greet() {}`
      `function respond() {}`
      src "function ask() {}"
    end
    # outputs:
    # function greet() {}
    # function respond() {}
    # function ask() {}
    ```

- [`#[]`][{Node#with}] interpolates data into placeholders. E.g.
    ```ruby
    Cecil::Code.generate_string do
      `function $fn() {}`["greet"]
      `function $fn() {}`[fn: "respond"]
    end
    # outputs:
    # function greet() {}
    # function respond() {}
    ```
- [`#[]`][{Node#with}]`{ ... }` given a block, interpolates and indents the code emitted in its block.
    E.g.
    ```ruby
    Cecil::Code.generate_string do
      `function $fn() {`["greet"] do
        `console.log("hello")`
      end
    end
    # outputs:
    # function greet() {
    #     console.log("hello")
    # }
    ```
- [`#<<`][{Node#<<}] adds code the last line of the block.
    E.g.
    ```ruby
    Cecil::Code.generate_string do
      `(function ${fn}Now() {`["greet"] do
        `console.log("hello")`
      end << ')()'
    end
    # outputs:
    # (function greetNow() {
    #     console.log("hello")
    # })()
    ```
- [`#content_for`][{BlockContext#content_for}] emits source code to different locations
- [`#defer`][{BlockContext#defer}] waits to emit the given source until after data has been gathered

### Customizing behavior for the language of the source code you're generating

Many of Cecil's defaults can be customized by creating a subclass of [`Cecil::Code`][{Code}] and overriding methods to customize syntax and behavior of:
- placeholder syntax
- indentation
- auto-closing brackets

Currently, Cecil comes with:
- [`Cecil::Code`][{Code}] for generic code
- [`Cecil::Lang::TypeScript`][{Lang::TypeScript}] for JavaScript and TypeScript


### Auto-closing brackets

> Customize which opening brackets are auto-closed by overriding [`Cecil::Code#block_ending_pairs`][{Code#block_ending_pairs}] in a subclass.

When nesting code blocks with `#[] { ... }`, open brackets at the end of the string get closed automatically.

For example, notice how we don't have to manually provide a closing `}` in the following:

```ruby
`$var = {`[var: "user"] do
  `id: 42`
end
```
becomes
```javascript
user = {
    id: 42
}
```

#### Multiple brackets

Every consecutive closing bracket at the end of the string gets closed. E.g.

```ruby
`$var = [{(`[var: "user"] do
  `id: 42`
end
```

becomes

```javascript
user = ([{
    id: 42
}])
```

Currently, the algorithm is simplistic, so open brackets that aren't at the end of the string will *not* get closed.

In this example, the `(` in `test(` needs to be closed manually:

```ruby
`test("getter $fn", () => {`[fn: 'getUsername'] do
  `assert(false)`
end << `)'
```

```javascript
test("getter getUsername", () => {
    assert(false)
})
```

### Placeholder syntax

Default placeholder rules:
- start with `$`-- e.g. `$foo`
- named with alpha-numeric and underscore -- e.g. `$foo_bar123`
- names can optionally be surrounded by optional brackets -- e.g  `${my_placeholder}`

Surrounding with brackets can be useful to separate a placeholder from subsequent characters that would otherwise get parsed as a placeholder.

E.g. `function ${fn}Sync()`-- without curly brackets, the placeholder would be parsed as `fnSync`.

Customize placeholder syntax by subclassing [`Cecil::Code`][{Code}]
and overriding [placeholder-related methods][{Code}].


### Helper methods

If you use your generator frequently it can be helpful to define reusable helper methods on a subclass of [`Cecil::Code`][{Code}].

For example, the [`Cecil::Lang::TypeScript`][{Lang::TypeScript}] subclass defines several [helper methods][{Lang::TypeScript::Helpers}] for generating TypeScript code.

[{BlockContext#content_for}]: https://www.rubydoc.info/github/nicholaides/cecil/main/Cecil/BlockContext#content_for-instance_method
[{BlockContext#defer}]: https://www.rubydoc.info/github/nicholaides/cecil/main/Cecil/BlockContext#defer-instance_method
[{BlockContext#src}]: https://www.rubydoc.info/github/nicholaides/cecil/main/Cecil/BlockContext#src-instance_method
[{BlockContext}]: https://www.rubydoc.info/github/nicholaides/cecil/main/Cecil/BlockContext
[{Code.generate_string}]: https://www.rubydoc.info/github/nicholaides/cecil/main/Cecil/Code#generate_string-class_method
[{Code.generate}]: https://www.rubydoc.info/github/nicholaides/cecil/main/Cecil/Code#generate-class_method
[{Code}]: https://www.rubydoc.info/github/nicholaides/cecil/main/Cecil/Code
[{Code#block_ending_pairs}]: https://www.rubydoc.info/github/nicholaides/cecil/main/Cecil/Code#block_ending_pairs-instance_method
[{Lang::TypeScript}]: https://www.rubydoc.info/github/nicholaides/cecil/main/Cecil/Lang/TypeScript
[{Lang::TypeScript::Helpers}]: https://www.rubydoc.info/github/nicholaides/cecil/main/Cecil/Lang/TypeScript/Helpers
[{Lang::TypeScript.generate_string}]: https://www.rubydoc.info/github/nicholaides/cecil/main/Cecil/Lang/TypeScript#generate_string-class_method
[{Lang::TypeScript.generate}]: https://www.rubydoc.info/github/nicholaides/cecil/main/Cecil/Code#generate-class_method
[{Node#<<}]: https://www.rubydoc.info/github/nicholaides/cecil/main/Cecil/Node#<<-instance_method
[{Node#with}]: https://www.rubydoc.info/github/nicholaides/cecil/main/Cecil/Node#with-instance_method

## Installation

From your shell:

```sh
bundle add cecil
```

In your Gemfile like:

```ruby
gem 'cecil'
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/nicholaides/cecil.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
