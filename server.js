const WebSocket = require('ws');
const http = require('http');

const PORT = process.env.PORT || 10000;
const server = http.createServer();

const wss = new WebSocket.Server({ server });

wss.on('connection', function connection(ws) {
  console.log('Client connected');

  ws.on('message', function incoming(message) {
    console.log('Received:', message.toString());
  });

  ws.send('Welcome to the WebSocket server!');
});

server.listen(PORT, () => {
  console.log(`Server is listening on port ${PORT}`);
});
