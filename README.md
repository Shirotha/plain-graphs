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

```toml
# edge from the 'a' node to the 'b' node with a string value
a.b = "value"
```
## Rules
Rules allow to normalize the data in a declaritive way.
They are stored in the `rules: list<record>` key.

### Filters
Select which nodes are affected.
- `from: one_of<string, list<string>>`: included node names (default: all)
- `not-from: one_of<string, list<string>>`: excluded node names (default: none)
- `to: one_of<string, list<string>>`: required connections (default: none)
- `not-to: one_of<string, list<string>>`: disqualifying connections (default: none)

### Actions
Changes applied to matching nodes.
- `default: record`: add connections if not already present
- `override: record`: add connections or replace if already present
- `skip: bool`: if `true`, will skip the entire node (see `into bool` for valid values)

## Examples
```toml
[[rules]]
default.mark = false

[a]
mark = true

[b]
```
```nu
use plain-graphs/
(plain-graphs $file | get b.mark) == false
```
