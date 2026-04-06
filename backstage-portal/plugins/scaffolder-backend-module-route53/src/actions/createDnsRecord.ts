import { createTemplateAction } from '@backstage/plugin-scaffolder-node';
import {
  Route53Client,
  ChangeResourceRecordSetsCommand,
} from '@aws-sdk/client-route-53';

export function createRoute53DnsRecordAction() {
  return createTemplateAction<{
    serviceName: string;
  }>({
    id: 'aws:route53:create-dns-record',
    description:
      'Creates a Route53 A alias record pointing {serviceName}.{domain} to the ALB',
    schema: {
      input: {
        type: 'object',
        required: ['serviceName'],
        properties: {
          serviceName: {
            type: 'string',
            title: 'Service name',
            description: 'Subdomain prefix (e.g. "demo3" creates demo3.backstage.glaciar.org)',
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
      const { serviceName } = ctx.input;

      const hostedZoneId = process.env.ROUTE53_HOSTED_ZONE_ID;
      const domainName = process.env.ROUTE53_DOMAIN_NAME;
      const albDnsName = process.env.ALB_DNS_NAME;
      const albHostedZoneId = process.env.ALB_HOSTED_ZONE_ID;

      if (!hostedZoneId || !domainName || !albDnsName || !albHostedZoneId) {
        throw new Error(
          'Missing Route53 environment variables. Ensure ROUTE53_HOSTED_ZONE_ID, ROUTE53_DOMAIN_NAME, ALB_DNS_NAME, and ALB_HOSTED_ZONE_ID are set.',
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
