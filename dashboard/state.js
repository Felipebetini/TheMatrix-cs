const params = new URLSearchParams(window.location.search);

export const S = {
  agentState:          {},
  events:              [],
  usage:               {},
  usageLive:           {},
  usageHistory:        [],
  usageRange:          '7',
  sessions:            [],
  dbHistory:           [],
  dbPatterns:          {},
  histProjectFilter:   '',
  activeTab:           'live',
  selectedSession:     params.get('session') || '',
  startedAt:           null,
  elapsedTimer:        null,
  lastEventsSignature: '',
  testMode:            params.get('mode') === 'test' || localStorage.getItem('matrixDashboardMode') === 'test',
};
