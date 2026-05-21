export function generateMockState() {
  const now   = Math.floor(Date.now() / 1000);
  const tools = ['read', 'edit', 'bash', 'agent', 'search'];
  const targets = [
    '~/Local Sites/imlab/app/public/wp-content/themes/custom/functions.php',
    '~/Documents/The Matrix/projects/imlab/CHANGELOG.md',
    'wp plugin list --status=active --format=table',
    'implementer: verify FIXED_WHEN against checkout flow',
    'error signature: checkout timeout',
  ];
  const idx = now % tools.length;
  return {
    status:       'active',
    agent:        'smith',
    project:      'imlab',
    model:        'claude-sonnet-4-6',
    tool_calls:   42 + (now % 19),
    gate_e_armed: (now % 9) > 5,
    last_tool:    { name: tools[idx], target: targets[idx] },
    started_at:   now - 1337,
  };
}

export function generateMockEvents() {
  const now     = Math.floor(Date.now() / 1000);
  const entries = [
    ['system', 'Test mode enabled',                                                             120],
    ['read',   '~/Local Sites/imlab/app/public/.ai-docs/AI_CONTEXT.md',                       4200],
    ['read',   '~/Documents/The Matrix/projects/imlab/RSI.yaml',                              1800],
    ['read',   '~/Documents/The Matrix/policies/SENTINELS.md',                               33000],
    ['search', 'checkout timeout signature in ERROR_SIGNATURES.md',                             890],
    ['agent',  'implementer started (risk: medium)',                                          22500],
    ['bash',   'curl -sIL https://example.com/checkout',                                        340],
    ['edit',   '~/Local Sites/imlab/app/public/wp-content/plugins/custom-plugin/checkout.php', 9800],
    ['edit',   '~/Local Sites/imlab/app/public/wp-content/plugins/custom-plugin/checkout.php', 6100],
    ['read',   '~/Documents/The Matrix/policies/SENTINELS.md',                                8400],
    ['read',   '~/Documents/The Matrix/policies/SENTINELS.md',                                8400],
    ['agent',  'reviewer PASS_WITH_NOTES',                                                   15200],
    ['system', 'Waiting for Felipe approval',                                                   210],
  ];
  return entries.map((x, i) => {
    const ts = now - i * 27;
    return { ts, iso: new Date(ts * 1000).toISOString(), tool: x[0], target: x[1], total_tokens: x[2] };
  });
}

export const MOCK_USAGE_LIVE = {
  totals: {
    total_tokens_including_cache: 134060,
    input_tokens:                  58200,
    output_tokens:                 12400,
    cache_read_tokens:             61800,
    cache_write_tokens:             1660,
  },
};
