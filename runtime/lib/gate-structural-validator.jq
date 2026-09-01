# Generic JSON Schema interpreter for Gate artifacts.
# Do not add Gate-specific paths or enum values here.

def type_ok($expected; $value):
  if ($expected | type) == "array"
  then any($expected[]; type_ok(.; $value))
  else
    if $expected == "object" then ($value | type) == "object"
    elif $expected == "array" then ($value | type) == "array"
    elif $expected == "string" then ($value | type) == "string"
    elif $expected == "number" then ($value | type) == "number"
    elif $expected == "integer" then
      (($value | type) == "number" and (($value | floor) == $value))
    elif $expected == "boolean" then ($value | type) == "boolean"
    elif $expected == "null" then ($value | type) == "null"
    else false
    end
  end;

def pointer_path($ref):
  ($ref | sub("^#/"; "") | split("/") |
    map(gsub("~1"; "/") | gsub("~0"; "~")));

def resolve_ref($root; $ref):
  if $ref == "#" then $root else ($root | getpath(pointer_path($ref))) end;

# $value is the observed value that caused this issue (null when there is no
# single observed value to show, e.g. a missing required property). Callers
# consuming only {path, message} are unaffected; the first-error extractor
# (gate_structural_schema_first_error in gate-structural-verify.sh) uses
# $value to produce a diagnostic message with the offending value included,
# so a handwritten verifier can rely on this generic error instead of
# hand-rolling its own "X is not one of A/B/C" message.
def issue($path; $message; $value):
  [{path:$path, message:$message, value:$value}];

def validate($root; $schema; $value; $path):
  if $schema == true then []
  elif $schema == false then issue($path; "schema rejected the value"; $value)
  elif ($schema | type) != "object" then issue($path; "invalid schema node"; null)
  else
    ([
      (if ($schema | has("$ref"))
       then validate($root; resolve_ref($root; $schema["$ref"]); $value; $path)
       else [] end),
      (if ($schema | has("type")) and
          (type_ok($schema.type; $value) | not)
       then issue($path; "expected type " + ($schema.type | tostring) +
         ", got " + ($value | type); $value) else [] end),
      (if ($schema | has("const")) and ($value != $schema.const)
       then issue($path; "value does not match const " +
         ($schema.const | tojson); $value) else [] end),
      (if ($schema | has("enum")) and
          (any($schema.enum[]; . == $value) | not)
       then issue($path; "value is outside enum " +
         ($schema.enum | tojson); $value) else [] end),
      (if ($value | type) == "string" and ($schema | has("pattern")) and
          (($value | test($schema.pattern)) | not)
       then issue($path; "string does not match pattern " +
         ($schema.pattern | tojson); $value) else [] end),
      (if ($value | type) == "string" and ($schema | has("minLength")) and
          (($value | length) < $schema.minLength)
       then issue($path; "string is shorter than minLength " +
         ($schema.minLength | tostring); $value) else [] end),
      (if ($value | type) == "string" and ($schema | has("maxLength")) and
          (($value | length) > $schema.maxLength)
       then issue($path; "string is longer than maxLength " +
         ($schema.maxLength | tostring); $value) else [] end),
      (if ($value | type) == "number" and ($schema | has("minimum")) and
          ($value < $schema.minimum)
       then issue($path; "number is below minimum " +
         ($schema.minimum | tostring); $value) else [] end),
      (if ($value | type) == "number" and ($schema | has("maximum")) and
          ($value > $schema.maximum)
       then issue($path; "number is above maximum " +
         ($schema.maximum | tostring); $value) else [] end),
      (if ($value | type) == "array" and ($schema | has("minItems")) and
          (($value | length) < $schema.minItems)
       then issue($path; "array is shorter than minItems " +
         ($schema.minItems | tostring); ($value | length)) else [] end),
      (if ($value | type) == "array" and ($schema | has("maxItems")) and
          (($value | length) > $schema.maxItems)
       then issue($path; "array is longer than maxItems " +
         ($schema.maxItems | tostring); ($value | length)) else [] end),
      (if ($value | type) == "array" and ($schema | has("uniqueItems")) and
          $schema.uniqueItems and (($value | unique | length) != ($value | length))
       then issue($path; "array items are not unique"; $value) else [] end),
      (if ($value | type) == "object" and ($schema | has("required"))
       then [$schema.required[] as $key |
         select(($value | has($key)) | not) |
         issue($path + "." + $key; "required property is missing"; null)[]]
       else [] end),
      (if ($value | type) == "object" and
          ($schema | has("additionalProperties")) and
          ($schema.additionalProperties == false)
       then [$value | keys[] as $key |
         select((($schema.properties // {}) | has($key)) | not) |
         issue($path + "." + $key; "additional property is not allowed";
           $value[$key])[]]
       else [] end),
      (if ($value | type) == "object"
       then [($schema.properties // {}) | to_entries[] as $entry |
         select($value | has($entry.key)) |
         validate($root; $entry.value; $value[$entry.key];
           $path + "." + $entry.key)[]]
       else [] end),
      (if ($value | type) == "array" and ($schema | has("items")) and
          ($schema.items | type) == "object"
       then [$value | to_entries[] |
         validate($root; $schema.items; .value;
           $path + "[" + (.key|tostring) + "]")[]]
       else [] end),
      (if ($value | type) == "array" and ($schema | has("contains")) and
          (any($value[]; (validate($root; $schema.contains; .; $path) | length) == 0) | not)
       then issue($path; "array does not contain a matching item"; null) else [] end),
      (if ($schema | has("allOf"))
       then [$schema.allOf[] | validate($root; .; $value; $path)[]]
       else [] end),
      (if ($schema | has("anyOf")) and
          (any($schema.anyOf[]; (validate($root; .; $value; $path) | length) == 0) | not)
       then issue($path; "value does not match anyOf"; $value) else [] end),
      (if ($schema | has("oneOf"))
       then ([$schema.oneOf[] | validate($root; .; $value; $path) |
               select(length == 0)] | length) as $matches |
         if $matches != 1
         then issue($path; "value does not match exactly one oneOf branch (matched " +
           ($matches | tostring) + ")"; null)
         else [] end
       else [] end),
      (if ($schema | has("not")) and
          ((validate($root; $schema.not; $value; $path) | length) == 0)
       then issue($path; "value matches forbidden not branch"; $value) else [] end),
      (if ($schema | has("if"))
       then if (validate($root; $schema.if; $value; $path) | length) == 0
            then (if ($schema | has("then"))
                  then validate($root; $schema.then; $value; $path) else [] end)
            else (if ($schema | has("else"))
                  then validate($root; $schema.else; $value; $path) else [] end)
            end
       else [] end)
    ] | add)
  end;

# An unknown schema name is an execution failure, not a validation failure:
# falling through to validate() would report it as "invalid schema node",
# i.e. as though the instance were malformed. Exit 9 keeps that distinction
# without a second jq process just to probe the bundle (9 avoids jq's own
# 1/2/3/5 exit codes).
if ($schemas[0] | has($name)) | not
then ("gate-structural-verify: unknown schema: " + $name + "\n") | halt_error(9)
else
  $schemas[0][$name] as $schema |
  validate($schema; $schema; $instance[0]; "$")
end
