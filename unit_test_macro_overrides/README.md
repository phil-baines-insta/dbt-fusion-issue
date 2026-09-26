# Unit test macro overrides break the package namespace (dbt 2.0.6)

In dbt 2.0.6, a unit test that overrides a package-qualified macro (e.g. `my_project.is_ci`) makes every other macro in that package undefined for the test. Calling any macro in the package that wasn't overridden fails with:

```
[error] [JinjaError (dbt1501)]: Failed to render SQL invalid operation: value of type undefined is not callable
```

The same tests pass on dbt-core 1.11.6.

## Layout

The layout mirrors a common setup: a project that owns the macros, plus a nested `integration_tests` project that installs it with `local: ..` and unit tests the macros through small ephemeral models.

```
my_project/
  macros/
    is_ci.sql            returns false
    pick_label.sql       returns 'ci' if my_project.is_ci() else 'local'
    unused.sql           never called by anything
  models/
    label.sql / .yml     same-project case
  integration_tests/
    packages.yml         local: ..
    models/
      test_pick_label.sql / .yml   cross-package case
```

Each project has three unit tests against a model that renders `my_project.pick_label()`:

| Test | Override | Expected |
|---|---|---|
| `*__no_override` | none | `local` |
| `*__override_called_macro` | `my_project.is_ci: true` | `ci` |
| `*__override_unrelated_macro` | `my_project.unused: stubbed` | `local` |

The unrelated-macro case matters: `pick_label` never calls `unused`, but overriding it still breaks `my_project.pick_label` itself.

## Running

Set `SNOWFLAKE_ACCOUNT`, `SNOWFLAKE_USER`, `SNOWFLAKE_PASSWORD`, `SNOWFLAKE_ROLE`, `SNOWFLAKE_WAREHOUSE`, `SNOWFLAKE_DATABASE` and `SNOWFLAKE_SCHEMA`, then from this directory:

```bash
export DBT_PROFILES_DIR="$(pwd)"

# same-project case
cd my_project
dbt build

# cross-package case
cd integration_tests
dbt deps
dbt build --exclude package:my_project
```

The tests use `given: []`, so they don't read any tables.

## Results

dbt 2.0.6:

```
same_project__no_override                 Passed
same_project__override_called_macro       Failed  value of type undefined is not callable
same_project__override_unrelated_macro    Failed  value of type undefined is not callable

cross_package__no_override                Passed
cross_package__override_called_macro      Failed  value of type undefined is not callable
cross_package__override_unrelated_macro   Failed  value of type undefined is not callable
```

dbt-core 1.11.6 with dbt-snowflake 1.11.2: all six pass.

The error location is also off. It points at the unit test yml file, but the line and column belong to the `my_project.pick_label()` call in the model SQL.

## Likely cause

`bind_override_macros` in `crates/dbt-tasks-sa/src/renderable/renderable/unit_test.rs` wraps the package namespace in an `ObjectOverlay` with the override stub first:

```rust
impl Object for ObjectOverlay {
    fn get_value(self: &Arc<Self>, key: &Value) -> Option<Value> {
        self.0
            .iter()
            // Err if undefined
            .filter_map(|o| o.get_item(key).ok())
            .next()
    }
}
```

`Value::get_item` returns `Ok(Value::UNDEFINED)` for a missing key and only errors when the receiver itself is undefined. So the stub map always answers first, and lookups for non-overridden macros never reach the real package namespace. Skipping undefined values should fix it:

```rust
self.0
    .iter()
    .find_map(|o| o.get_item_opt(key).filter(|v| !v.is_undefined()))
```

With the lookup fixed, `*__override_called_macro` also checks that a stubbed macro is seen by the macros that call it (`pick_label` calling `my_project.is_ci`), which is how dbt-core behaves.
