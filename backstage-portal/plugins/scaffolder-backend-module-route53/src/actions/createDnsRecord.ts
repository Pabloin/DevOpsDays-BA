import { createTemplateAction } from '@backstage/plugin-scaffolder-node';
import {
  Route53Client,
  ChangeResourceRecordSetsCommand,
} from '@aws-sdk/client-route-53';

export function createRoute53DnsRecordAction() {
  return createTemplateAction<{
    serviceName: string;
    environment?: string;
  }>({
    id: 'aws:route53:create-dns-record',
    description:
      'Creates a Route53 A alias record pointing {serviceName}.{env}.backstage.{domain} to the correct environment ALB',
    schema: {
      input: {
        type: 'object',
        required: ['serviceName'],
        properties: {
          serviceName: {
            type: 'string',
            title: 'Service name',
            description: 'Subdomain prefix (e.g. "demo3" creates demo3.dev.backstage.glaciar.org)',
          },
          environment: {
            type: 'string',
            title: 'Target environment',
            description: 'dev or prod — determines which ALB and subdomain to use',
            enum: ['dev', 'prod'],
          },
        },
      },
      output: {
        type: 'object',
        properties: {
          fqdn: {
            type: 'string',
            title: 'Fully qualified domain name created',
          },
        },
      },
    },
    async handler(ctx) {
      const { serviceName, environment = 'dev' } = ctx.input;

      const hostedZoneId = process.env.ROUTE53_HOSTED_ZONE_ID;
      const albHostedZoneId = process.env.ALB_HOSTED_ZONE_ID;

      // Pick ALB and domain based on environment
      const albDnsName = environment === 'prod'
        ? process.env.APPS_PROD_ALB_DNS_NAME
        : process.env.APPS_DEV_ALB_DNS_NAME;
      const domainName = environment === 'prod'
        ? process.env.APPS_PROD_DOMAIN_NAME
        : process.env.APPS_DEV_DOMAIN_NAME;

      if (!hostedZoneId || !domainName || !albDnsName || !albHostedZoneId) {
        throw new Error(
          `Missing Route53 environment variables for environment "${environment}". ` +
          `Ensure ROUTE53_HOSTED_ZONE_ID, ALB_HOSTED_ZONE_ID, APPS_DEV_ALB_DNS_NAME, APPS_DEV_DOMAIN_NAME, ` +
          `APPS_PROD_ALB_DNS_NAME, and APPS_PROD_DOMAIN_NAME are set.`,
        );
      }

      const fqdn = `${serviceName}.${domainName}`;

      ctx.logger.info(`Creating Route53 A alias record: ${fqdn} -> ${albDnsName}`);

      const client = new Route53Client({});

      await client.send(
        new ChangeResourceRecordSetsCommand({
          HostedZoneId: hostedZoneId,
          ChangeBatch: {
            Comment: `Scaffolder: create DNS record for ${serviceName}`,
            Changes: [
              {
                Action: 'UPSERT',
                ResourceRecordSet: {
                  Name: fqdn,
                  Type: 'A',
                  AliasTarget: {
                    DNSName: albDnsName,
                    HostedZoneId: albHostedZoneId,
                    EvaluateTargetHealth: true,
                  },
                },
              },
            ],
          },
        }),
      );

      ctx.logger.info(`DNS record created: ${fqdn}`);
      ctx.output('fqdn', fqdn);
    },
  });
}
