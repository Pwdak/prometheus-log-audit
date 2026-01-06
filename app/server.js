const express = require('express');
const client = require('prom-client');
const fs = require('fs');
const path = require('path');

const app = express();
const register = new client.Registry();
const logFile = '/logs/app.log';
fs.mkdirSync(path.dirname(logFile), { recursive: true });
function log(level, msg, extra = {}) {
  const line = JSON.stringify({ ts: new Date().toISOString(), level, msg, ...extra }) + '\n';
  fs.appendFile(logFile, line, () => {});
}

// Create metrics
const httpRequestDuration = new client.Histogram({
  name: 'http_request_duration_seconds',
  help: 'Duration of HTTP requests in seconds',
  labelNames: ['method', 'route', 'status_code'],
  buckets: [0.1, 0.3, 0.5, 0.7, 1, 3, 5, 7, 10]
});

const httpRequestTotal = new client.Counter({
  name: 'http_requests_total',
  help: 'Total number of HTTP requests',
  labelNames: ['method', 'route', 'status_code']
});

const memoryUsage = new client.Gauge({
  name: 'app_memory_usage_bytes',
  help: 'Memory usage of the application'
});

const dbConnections = new client.Gauge({
  name: 'db_connections_active',
  help: 'Number of active database connections'
});

const cacheHitRate = new client.Gauge({
  name: 'cache_hit_rate',
  help: 'Cache hit rate percentage'
});

register.registerMetric(httpRequestDuration);
register.registerMetric(httpRequestTotal);
register.registerMetric(memoryUsage);
register.registerMetric(dbConnections);
register.registerMetric(cacheHitRate);

// Simulate database and cache without actual connections
// This simulates metrics as if we had real DB/Cache connections

// Simulate varying metrics
setInterval(() => {
  const usage = process.memoryUsage();
  memoryUsage.set(usage.heapUsed);
  
  // Simulate varying DB connections
  const baseConnections = 10;
  const variance = Math.sin(Date.now() / 10000) * 8;
  dbConnections.set(baseConnections + variance);
  
  // Simulate cache hit rate variations
  const baseHitRate = 75;
  const hitVariance = Math.sin(Date.now() / 5000) * 20;
  cacheHitRate.set(baseHitRate + hitVariance);
}, 5000);

// Middleware to track requests
app.use((req, res, next) => {
  const start = Date.now();
  res.on('finish', () => {
    const duration = (Date.now() - start) / 1000;
    httpRequestDuration.observe(
      { method: req.method, route: req.path, status_code: res.statusCode },
      duration
    );
    httpRequestTotal.inc({ 
      method: req.method, 
      route: req.path, 
      status_code: res.statusCode 
    });
    const level = duration > 1 ? 'WARN' : 'INFO';
    log(level, 'http_request', { method: req.method, route: req.path, status_code: res.statusCode, duration });
  });
  next();
});

// Routes
app.get('/', (req, res) => {
  res.json({ message: 'Hello from monitored app!' });
  log('INFO', 'root_accessed');
});

app.get('/slow', async (req, res) => {
  // Simulate slow endpoint
  const delay = Math.random() * 2000;
  await new Promise(resolve => setTimeout(resolve, delay));
  res.json({ message: 'Slow response', delay });
  log('WARN', 'slow_endpoint', { delay });
});

app.get('/db', async (req, res) => {
  // Simulate database query
  const delay = Math.random() * 200;
  await new Promise(resolve => setTimeout(resolve, delay));
  res.json({ 
    time: new Date().toISOString(),
    simulated: true 
  });
  log('INFO', 'db_query', { delay });
});

app.get('/cache', async (req, res) => {
  // Simulate cache operation
  const delay = Math.random() * 50;
  await new Promise(resolve => setTimeout(resolve, delay));
  res.json({ 
    cached: 'test-value',
    simulated: true 
  });
  log('DEBUG', 'cache_hit', { delay });
});

// Metrics endpoint
app.get('/metrics', async (req, res) => {
  res.set('Content-Type', register.contentType);
  res.end(await register.metrics());
  log('INFO', 'metrics_scraped');
});

const PORT = 3000;
app.listen(PORT, '0.0.0.0', () => {
  console.log(`App running on port ${PORT}`);
  log('INFO', 'app_started', { port: PORT });
});
