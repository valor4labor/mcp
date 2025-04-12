console.log('Test server starting...');
const http = require('http');
const server = http.createServer((req, res) => {
  res.writeHead(200, {'Content-Type': 'application/json'});
  res.end(JSON.stringify({status: 'ok', server: 'test-mcp'}));
});
server.listen(3099, () => console.log('Test server running on port 3099'));
process.on('SIGINT', () => {
  console.log('Test server stopping...');
  server.close();
});