# Testing

::: danger ALPHA
* TODO: document testing patterns
:::

Configuring rspec to treat files in spec/actions as service specs:

```ruby
config.define_derived_metadata(file_path: %r{spec/actions}) do |metadata|
  metadata[:type] = :service
end
```
