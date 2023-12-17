# Cecil

An experimental templating library for generating source code. Leverages Ruby's flexible syntax so that your templates can look as much like their output as possible.

## Features

### It's just Ruby

Pass a block to Cecil and use backticks (or use `src` if you prefer) to add lines of source code. Cecil will return your generated source code as a string.

Example:

```ruby
model_code = Cecil::Code.generate_string do
  `import Model from '../model'`

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

outputs:

```typescript
import Model from '../model'
class User extends Model {
  id: number
  name: string
  companyId: number | undefined
}
export type Username = User['name']
```

### Interpolation with high fidelity to intended output

Use `#[]` on the backticks to replace placeholders with actual values.

By default, placeholders start with `$` and are followed by an identifier.

Positional arguments match up with placeholders in order. Named arguments match placeholders by name.

Example:

```ruby
field = "user"
types = ["string", "string[]"]
default_value = ["SilentHaiku", "DriftingSnowfall"]
field_class = "Model"

Cecil::Code.generate_string do
  # positional
  `let $field: $FieldType = $default`[field, types.join('|'), default_value.sort.to_json]

  # named
  `let $field: $FieldClass<$Types> | null = new $FieldClass($default)`[
    field: field,
    FieldClass: field_class,
    Types: types.join('|'),
    default: default_value.sort.to_json
  ]
end
```

returns:

```typescript
let user: string|string[] = ["DriftingSnowfall","SilentHaiku"]
let user: Model<string|string[]> | null = new Model(["DriftingSnowfall","SilentHaiku"])
```

### Indent code blocks & close brackets automatically

A block passed to `#[]` gets indented and open brackets get closed automatically.

Example:

```ruby
model = "User"
field_name = "name"
field_default = "Unnamed"

Cecil::Code.generate_string do
  `class $Class extends Model {`[model] do
    `id: number`

    `override get $field() {`[field_name] do
      `return super.$field ?? $defaultValue`[field_name, field_default.to_json]
    end
  end
end
```

returns:

```typescript
class User extends Model {
    id: number
    override get name() {
        return super.name ?? "Unnamed"
    }
}
```

### Emit code earlier or later in the file

`content_for` can be used to add content to a different location of your file without having to iterate through your data multitple times.

Call `content_for(some_key) { ... }` with key and a block to store content under the key you provide. Call `content_for(some_key)` with the key and *no* block to insert your stored content at that location.

Example:

```ruby
models = [
  { name: 'User', inherits: 'AuthModel' },
  { name: 'Company', inherits: 'Model' },
]

Cecil::Code.generate_string do
  content_for :imports

  models.each do |model|
    ``
    `class $Class extends $SuperClass {`[model[:name], model[:inherits]] do
      `id: number`
    end

    content_for :imports do
      `import $SuperClass from '../models/$SuperClass'`[SuperClass: model[:inherits]]
    end

    content_for :registrations do
      `$SuperClass.registerAncestor($Class)`[model[:inherits], model[:name]]
    end
  end

  ``
  content_for :registrations
end
```

returns:

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

### Collect data as you go, then use it earlier in the document

The `#defer` method takes a block and waits to call it until the rest of the template is evaluated. The block's result is inserted at the location where `#defer` was called.

This gives a similar ability to `#content_for`, but is more flexible because you can collect any kind of data, not just source code.

Example:

```ruby
models = [
  { name: 'User', inherits: 'AuthModel' },
  { name: 'Company', inherits: 'Model' },
  { name: 'Candidate', inherits: 'AuthModel' },
]

Cecil::Code.generate_string do
  superclasses = []
  defer do
    `import { $SuperClasses } from '../models'`[superclasses.uniq.sort.join(', ')]
    ``
  end

  models.each do |model|
    superclasses << model[:inherits]

    `class $Class extends $SuperClass {}`[model[:name], model[:inherits]]
  end
end
```

returns:

```typescript
import { AuthModel, Model } from '../models'

class User extends AuthModel {}
class Company extends Model {}
class Candidate extends AuthModel {}
```

## Installation

Gem can be installed from github. Once I'm ready to bother with version numbers and releases and such, then I'll publish to Rubygems.

From your shell:

```sh
bundle add cecil --github=nicholaides/cecil
```

Add it to your Gemfile like:

```ruby
gem 'cecil', github: 'nicholaides/cecil'
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/nicholaides/cecil.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
