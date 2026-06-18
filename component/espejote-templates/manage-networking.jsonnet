local esp = import 'espejote.libsonnet';

local networking = import 'appuio-networking/networking.libsonnet';
local spec = import 'appuio-networking/spec.json';

local filterConfigmaps(configmaps) =
  local nameField = function(obj) obj.metadata.name;
  std.filter(
    function(obj) std.objectHas(obj.data, 'spec'),
    std.sort(configmaps, nameField)
  );

local configmapsConfig = filterConfigmaps(esp.context().configmaps_config);
local configmapsOperator = filterConfigmaps(esp.context().configmaps_operator);

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

local targetMetadata(configmaps) =
  local cmNames = std.map(
    function(obj) obj.metadata.name,
    configmaps
  );
  {
    annotations+: {
      'network.openshift-config.syn.tools/active-configmaps': std.manifestJsonMinified(cmNames),
    },
    labels+: {
      'app.kubernetes.io/managed-by': 'espejote',
    },
  };

local mergeSpec(configmaps, spec) =
  local cmSpecs = std.map(
    function(obj) std.parseJson(std.get(obj.data, 'spec', '')),
    configmaps
  );
  std.foldl(
    function(a, b) a + makeMergeable(b),
    cmSpecs + [ spec ],
    {}
  );

[
  networking.Config {
    metadata+: targetMetadata(configmapsConfig),
    spec: mergeSpec(configmapsConfig, spec.config),
  },
  networking.Operator {
    metadata+: targetMetadata(configmapsOperator),
    spec: mergeSpec(configmapsOperator, spec.operator),
  },
]
