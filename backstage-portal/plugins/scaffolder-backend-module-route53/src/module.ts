import { createBackendModule } from '@backstage/backend-plugin-api';
import { scaffolderActionsExtensionPoint } from '@backstage/plugin-scaffolder-node/alpha';
import { createRoute53DnsRecordAction } from './actions/createDnsRecord';

export const scaffolderBackendModuleRoute53 = createBackendModule({
  pluginId: 'scaffolder',
  moduleId: 'route53',
  register(env) {
    env.registerInit({
      deps: {
        scaffolder: scaffolderActionsExtensionPoint,
      },
      async init({ scaffolder }) {
        scaffolder.addActions(createRoute53DnsRecordAction());
      },
    });
  },
});
