const WebSocket = require("ws");
const http = require("http");
const express = require("express");
const cors = require("cors");
const bodyParser = require("body-parser");
const app = express();

const PORT = process.env.PORT || 10000;
const server = http.createServer();
const wss = new WebSocket.Server({ server });

let mobileClients = [];
let adminClients = [];

wss.on("connection", function connection(ws) {
  ws.send(
    JSON.stringify({ type: "HELLO", message: "Identify as ADMIN or MOBILE" })
  );

  ws.on("message", function incoming(message) {
    try {
      const data = JSON.parse(message);

      // Identification
      if (data.type === "IDENTIFY") {
        if (data.role === "ADMIN") {
          adminClients.push(ws);
          ws.send(
            JSON.stringify({ type: "INFO", message: "Identified as ADMIN" })
          );
        } else if (data.role === "MOBILE") {
          mobileClients.push(ws);
          ws.send(
            JSON.stringify({ type: "INFO", message: "Identified as MOBILE" })
          );
        }
        return;
      }

      // Admin sending command to all mobiles
      if (data.type === "COMMAND" && data.to === "MOBILE") {
        mobileClients.forEach((client) => {
          if (client.readyState === WebSocket.OPEN) {
            client.send(
              JSON.stringify({ type: "COMMAND", command: data.command })
            );
          }
        });
        return;
      }

      // Mobile sending response to all admins
      if (data.type === "RESPONSE" && data.to === "ADMIN") {
        adminClients.forEach((admin) => {
          if (admin.readyState === WebSocket.OPEN) {
            admin.send(
              JSON.stringify({
                type: "RESPONSE",
                from: "MOBILE",
                data: data.data,
              })
            );
          }
        });
        return;
      }
    } catch (err) {
      ws.send(JSON.stringify({ type: "ERROR", message: "Invalid JSON" }));
    }
  });

  ws.on("close", () => {
    mobileClients = mobileClients.filter((c) => c !== ws);
    adminClients = adminClients.filter((c) => c !== ws);
  });
});

server.listen(PORT, () => {
  console.log(`WebSocket server running on port ${PORT}`);
});

app.use(cors());
app.use(bodyParser.json());
app.use(bodyParser.urlencoded({ extended: true }));
app.get("/", (req, res) => {
  res.sendFile(__dirname + "/index.html");
});
