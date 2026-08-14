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

def issue($path; $message):
  [{path:$path, message:$message}];

def validate($root; $schema; $value; $path):
  if $schema == true then []
  elif $schema == false then issue($path; "schema rejected the value")
  elif ($schema | type) != "object" then issue($path; "invalid schema node")
  else
    ([
      (if ($schema | has("$ref"))
       then validate($root; resolve_ref($root; $schema["$ref"]); $value; $path)
       else [] end),
      (if ($schema | has("type")) and
          (type_ok($schema.type; $value) | not)
       then issue($path; "expected type " + ($schema.type | tostring) +
         ", got " + ($value | type)) else [] end),
      (if ($schema | has("const")) and ($value != $schema.const)
       then issue($path; "value does not match const") else [] end),
      (if ($schema | has("enum")) and
          (any($schema.enum[]; . == $value) | not)
       then issue($path; "value is outside enum") else [] end),
      (if ($value | type) == "string" and ($schema | has("pattern")) and
          (($value | test($schema.pattern)) | not)
       then issue($path; "string does not match pattern") else [] end),
      (if ($value | type) == "string" and ($schema | has("minLength")) and
          (($value | length) < $schema.minLength)
       then issue($path; "string is shorter than minLength") else [] end),
      (if ($value | type) == "string" and ($schema | has("maxLength")) and
          (($value | length) > $schema.maxLength)
       then issue($path; "string is longer than maxLength") else [] end),
      (if ($value | type) == "number" and ($schema | has("minimum")) and
          ($value < $schema.minimum)
       then issue($path; "number is below minimum") else [] end),
      (if ($value | type) == "number" and ($schema | has("maximum")) and
          ($value > $schema.maximum)
       then issue($path; "number is above maximum") else [] end),
      (if ($value | type) == "array" and ($schema | has("minItems")) and
          (($value | length) < $schema.minItems)
       then issue($path; "array is shorter than minItems") else [] end),
      (if ($value | type) == "array" and ($schema | has("maxItems")) and
          (($value | length) > $schema.maxItems)
       then issue($path; "array is longer than maxItems") else [] end),
      (if ($value | type) == "array" and ($schema | has("uniqueItems")) and
          $schema.uniqueItems and (($value | unique | length) != ($value | length))
       then issue($path; "array items are not unique") else [] end),
      (if ($value | type) == "object" and ($schema | has("required"))
       then [$schema.required[] as $key |
         select(($value | has($key)) | not) |
         issue($path + "." + $key; "required property is missing")[]]
       else [] end),
      (if ($value | type) == "object" and
          ($schema | has("additionalProperties")) and
          ($schema.additionalProperties == false)
       then [$value | keys[] as $key |
         select((($schema.properties // {}) | has($key)) | not) |
         issue($path + "." + $key; "additional property is not allowed")[]]
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
       then issue($path; "array does not contain a matching item") else [] end),
      (if ($schema | has("allOf"))
       then [$schema.allOf[] | validate($root; .; $value; $path)[]]
       else [] end),
      (if ($schema | has("anyOf")) and
          (any($schema.anyOf[]; (validate($root; .; $value; $path) | length) == 0) | not)
       then issue($path; "value does not match anyOf") else [] end),
      (if ($schema | has("oneOf"))
       then ([$schema.oneOf[] | validate($root; .; $value; $path) |
               select(length == 0)] | length) as $matches |
         if $matches != 1
         then issue($path; "value does not match exactly one oneOf branch")
         else [] end
       else [] end),
      (if ($schema | has("not")) and
          ((validate($root; $schema.not; $value; $path) | length) == 0)
       then issue($path; "value matches forbidden not branch") else [] end),
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

$schemas[0][$name] as $schema |
validate($schema; $schema; $instance[0]; "$")
