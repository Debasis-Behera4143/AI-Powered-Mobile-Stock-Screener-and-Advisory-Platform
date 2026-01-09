const express = require("express");
const app = express();

app.use(express.json());

app.use("/stocks", require("./routes/stocks.routes"));

app.get("/health", (req, res) => {
  res.send("Backend is healthy");
});

module.exports = app;
