const WebSocket = require("ws");
const http = require("http");
const fs = require("fs");
const path = require("path");

const PORT = process.env.PORT || 10000;

const server = http.createServer((req, res) => {
  if (req.url === "/status") {
    res.writeHead(200, { "Content-Type": "application/json" });
    res.end(
      JSON.stringify({
        mobileClients: mobileClients.length,
        adminClients: adminClients.length,
        totalClients: wss.clients.size,
      })
    );
    return;
  }

  // Serve the HTML page
  let filePath = "./public" + req.url;
  if (filePath === "./public/") filePath = "./public/index.html";

  const extname = String(path.extname(filePath)).toLowerCase();
  const mimeTypes = {
    ".html": "text/html",
    ".js": "application/javascript",
  };

  fs.readFile(filePath, (error, content) => {
    if (error) {
      res.writeHead(404);
      res.end("Not Found");
    } else {
      res.writeHead(200, {
        "Content-Type": mimeTypes[extname] || "text/plain",
      });
      res.end(content, "utf-8");
    }
  });
});

const wss = new WebSocket.Server({ server });

let mobileClients = [];
let adminClients = [];

wss.on("connection", function connection(ws) {
  console.log("New client connected");
  ws.send(
    JSON.stringify({
      type: "HELLO",
      message: "Identify as ADMIN or MOBILE",
      command: "PING",
    })
  );
// Broadcast to all clients including sender
  ws.on('message', (data) => {
    const msg = JSON.parse(data);
    const payload = JSON.stringify(msg);

    for (let client of clients) {
      if (client.readyState === WebSocket.OPEN) {
        client.send(payload);
      }
    }
  });


  // ws.on("message", function incoming(message) {
  //   try {
  //     const data = JSON.parse(message);
  //     console.log(`[>] ${message.toString()}`);

  //     if (data.type === "IDENTIFY") {
  //       if (data.role === "ADMIN") {
  //         adminClients.push(ws);
  //         ws.send(
  //           JSON.stringify({ type: "INFO", message: "Identified as ADMIN !" })
  //         );
  //       } else if (data.role === "MOBILE") {
  //         mobileClients.push(ws);
  //         ws.send(
  //           JSON.stringify({ type: "INFO", message: "Identified as MOBILE" })
  //         );
  //       }
  //       return;
  //     }

  //     if (data.type === "COMMAND" && data.to === "MOBILE") {
  //       mobileClients.forEach((client) => {
  //         if (client.readyState === WebSocket.OPEN) {
  //           client.send(
  //             JSON.stringify({ type: "COMMAND", command: data.command })
  //           );
  //         }
  //       });
  //       return;
  //     }

  //     if (data.type === "RESPONSE" && data.to === "ADMIN") {
  //       adminClients.forEach((admin) => {
  //         if (admin.readyState === WebSocket.OPEN) {
  //           admin.send(JSON.stringify({ type: "RESPONSE", data: data.data }));
  //         }
  //       });
  //       return;
  //     }
  //   } catch (err) {
  //     ws.send(JSON.stringify({ type: "ERROR", message: "Invalid JSON" }));
  //   }
  // });

  ws.on("close", () => {
    mobileClients = mobileClients.filter((c) => c !== ws);
    adminClients = adminClients.filter((c) => c !== ws);
    console.log("Client disconnected");
    console.log(`Mobile clients: ${mobileClients.length}`);
  });
});

server.listen(PORT, () => {
  console.log(`Server listening on http://localhost:${PORT}`);
});
