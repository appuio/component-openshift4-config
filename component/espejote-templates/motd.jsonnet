local esp = import 'espejote.libsonnet';
local config = import 'motd/config.json';

local formatConsoleNotification(cn) =
  local text = cn.spec.text;
  local link = if std.objectHas(cn.spec, 'link') then
    std.join(': ', [ std.get(cn.spec.link, 'text', 'link'), std.get(cn.spec.link, 'href') ]);
  std.join('\n', [ text, link ]);

local synMessages = std.prune([ config.motd.messages[m] for m in std.objectFields(config.motd.messages) ]);

local consoleMessages = [ formatConsoleNotification(n) for n in esp.context().consolenotifications ];

local messages = if config.motd.include_console_notifications then
  synMessages + consoleMessages
else
  synMessages;

local sep = '\n----------------------------------------\n';

local makeMotdCM(m=[]) =
  {
    apiVersion: 'v1',
    kind: 'ConfigMap',
    metadata: {
      name: 'motd',
      namespace: 'openshift',
    },
    data: {
      message: sep + std.join(sep, m) + sep,
    },
  };

if std.length(messages) > 0 then
  makeMotdCM(messages)
else
  esp.markForDelete(makeMotdCM())
