# Plain Graphs
Handle graph data stored in plain text formats.

## Usage
Can be used as a command
```nu
^plain-graphs $file ...$values
```
or can be included as a module
```nu
use plain-graphs/
```

> [!TIP]
> The command version can be used as a shebang line inside the data-file itself.

## Formats
Any format with a `from *` and `to *` (only for editing) sub-command that produces a `record` is supported.

## Data
Graphs are stored by declaring edges as nested dictionaries.
The values of the inner dictionary can be arbitrary data and is not touched by this tool.

Keys starting with '_' are reserved.

```toml
# edge from the 'a' node to the 'b' node with a string value
a.b = "value"

# use table notation to define multiple edges at once
[b]
a = 42
c = [1, 2, 3]

# use lists to store node groups (the key will be 'c.0' here)
[[cs]]
a = {x = 1, y = -1}
```
## Rules
Rules allow to normalize the data in a declarative way.
They are stored in the `_rules: list<record>` key.

### Filters
Select which nodes are affected.
- `from: one_of<string, list<string>>`: included node types (default: all)
- `not-from: one_of<string, list<string>>`: excluded node types (default: none)
- `to: one_of<string, list<string>>`: required connections (default: none)
- `not-to: one_of<string, list<string>>`: disqualifying connections (default: none)

### Node Types
By default the type of each node is its name.
This can be overridden by setting `<node>._type = "<type>"`.

> [!NOTE]
> The type of note groups is their declared name without the index.

> [!TIP]
> Use namespaces to specify the `_type` of multiple nodes at once
> by placing them in `_type.<type>`

### Actions
Changes applied to matching nodes.
- `default: record`: add connections if not already present
- `override: record`: add connections or replace if already present
- `skip: bool`: if `true`, will skip the entire node (see `into bool` for valid values)

## Examples
```toml
[[_rules]]
default.mark = false

[a]
mark = true

[b]
```
```nu
use plain-graphs/
(plain-graphs $file | get b.mark) == false
```
