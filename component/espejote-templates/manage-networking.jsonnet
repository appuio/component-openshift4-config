local esp = import 'espejote.libsonnet';

local networking = import 'appuio-networking/networking.libsonnet';
local spec = import 'appuio-networking/spec.json';

local parseConfigmaps(configmaps) =
  local nameField = function(obj) obj.metadata.name;
  std.map(
    function(obj) std.get(obj.data, 'spec', {}),
    std.sort(configmaps, nameField)
  );

local configmapsConfig = parseConfigmaps(esp.context().configmaps_config);
local configmapsOperator = parseConfigmaps(esp.context().configmaps_operator);

// Builds a new object from its input.
// All keys which contain an object or array will be suffixed with `+` in the result.
local makeMergeable(o) = {
  [key]+: makeMergeable(o[key])
  for key in std.objectFields(o)
  if std.isObject(o[key])
} + {
  [key]+: o[key]
  for key in std.objectFields(o)
  if std.isArray(o[key])
} + {
  [key]: o[key]
  for key in std.objectFields(o)
  if !std.isObject(o[key]) && !std.isArray(o[key])
};

local mergeSpec(configmaps, spec) = std.foldl(
  function(a, b) a + makeMergeable(b),
  configmaps + [ spec ],
  {}
);

[
  networking.Config {
    spec: mergeSpec(configmapsConfig, spec.config),
  },
  networking.Operator {
    spec: mergeSpec(configmapsConfig, spec.operator),
  },
]
