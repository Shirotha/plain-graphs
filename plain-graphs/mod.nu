#! /usr/bin/env nu

def upsert-node [
  node: string
  update: closure
]: record -> record {
  let edges = $in | get -i $node
  $in | upsert $node {(do $update $edges)}
}

def merge-nodes [
  rhs: record
]: record -> record {
  let lhs = $in
  $rhs | transpose node edges | reduce --fold $lhs {|element, result|
    $result | upsert-node $element.node {|old| $old | default {} | merge $element.edges }
  }
}

def parse-rules [
]: any -> list<record> {
  if ($in | describe -d).type != list { return [] }
  $in | enumerate | each {|element|
    mut rule = $element.item
    if ($rule | describe -d).type != record {
      print -e $'warning: rule ($element.index): expected a record value'
      return
    }
    if 'from' in $rule {
      $rule.from = ([$rule.from] | flatten | each { into string })
    }
    if 'not-from' in $rule {
      $rule.not-from = ([$rule.not-from] | flatten | each { into string })
    }
    if 'to' in $rule {
      $rule.to = ([$rule.not-to] | flatten | each { into string })
    }
    if 'not-to' in $rule {
      $rule.not-to = ([$rule.not-to] | flatten | each { into string })
    }

    mut has_effect = false
    if ($rule.default? | describe -d).type == record and ($rule.default | is-not-empty) {
      $has_effect = true
    }
    if ($rule.override? | describe -d).type == record and ($rule.override | is-not-empty) {
      $has_effect = true
    }
    if 'skip' in $rule {
      $rule.skip = ($rule.skip | into bool)
      if $rule.skip { $has_effect = true }
    }
    if $has_effect { $rule }
  }
}

def apply-rules [
  node: string
  rules: list<record>
]: record -> record {
  let edges = $in
  $rules | reduce --fold $edges {|rule, edges|
    if $edges == null { return }
    if 'from' in $rule and not $node in $rule.from { return $edges }
    if 'not-from' in $rule and $node in $rule.from { return $edges }
    if 'to' in $rule and not ($edges | columns | all { $in in $rule.to }) { return $edges }
    if 'not-to' in $rule and ($edges | columns | any { $in in $rule.not-to }) { return $edges }
    if ($rule.skip? | default false) { return }
    $rule.default? | default {} | merge $edges | merge ($rule.override? | default {})
  }
}

def load-graph [
  --invert (-i)
  --no-rules (-R)
]: path -> record {
  let data = $in | open
  if ($data | describe -d).type != record {
    error make { msg: 'file does not contain valid graph data' }
  }
  let rules = if $no_rules { [] } else {
    $data.rules? | default [] | parse-rules
  }
  if $invert {
    mut result = {}
    for node in ($data | transpose name edges) {
      if ($node.edges | describe -d).type == record {
        for edge in ($node.edges | transpose name value) {
          $result = ($result | upsert-node $edge.name {|old| $old | default {} | insert $node.name $edge.value })
        }
      }
    }
    $result
  } else {
    $data | items {|node, edges|
      if ($edges | describe -d).type != record { return }
      let edges = $edges | apply-rules $node $rules
      if $edges != null { [$node $edges] }
    } | compact | into record
  }
}

def parse-value [
  --invert (-i)
]: any -> record {
  mut value = $in
  if ($value | describe -d).type == string {
    $value = $value | from toml
  }
  if ($value | describe -d).type != record {
    make error { msg: 'value is invalid' }
  }
  if $invert {
    $value | items {|node, edges|
      if ($edges | describe -d).type != record { return }
      $edges | items {|edge, value| [$edge {$node: $value}] } | into record
    } | compact | reduce {|a, b| $a | merge-nodes $b }
  } else { $value }
}

def merge-graph [
  --invert (-i)
  --replace (-r)
  ...value: any
]: path -> list {
  let data = $in | open
  if ($data | describe -d).type != record {
    error make { msg: 'file does not contain valid graph data' }
  }
  $value | reduce --fold $data {|value, data|
    $value | parse-value --invert=$invert | transpose node edges | reduce --fold $data {|element, data|
      if ($data | get -i $element.node | default {} | describe -d).type != record {
        print -e $'warning: node ($element.node): skipped invalid node'
        return $data
      }
      let edges = $element.edges
      if ($element.edges | describe -d).type == record {
        $data | upsert-node $element.node {|old|
          if $replace or ($old | describe -d).type != record { $edges } else {
            $old | merge $edges
          }
        }
      } else if ($data | get -i $element.node | describe -d).type == record {
        $data | reject $element.node
      } else { $data }
    }
  }
}

export def main [
  --invert (-i) # invert edges in input value and output
  --replace (-r) # instead of merging conflicts, replace existing nodes
  --no-rules (-R) # skip applying rules
  --print (-p) # print result to stdout instead of saving
  data: path
  ...value: any
] {
  if ($value | is-empty) {
    $data | load-graph --invert=$invert --no-rules=$no_rules
  } else {
    let result = $data | merge-graph --invert=$invert --replace=$replace ...$value
    if $print {
      $result
    } else {
      $result | save --force $data
    }
  }
}
