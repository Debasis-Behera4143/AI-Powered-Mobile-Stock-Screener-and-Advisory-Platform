const express = require("express");
const router = express.Router();

const {
  fetchAndStoreStock,
  getStocks,
} = require("../controllers/stocks.controller");

router.post("/fetch", fetchAndStoreStock);
router.get("/", getStocks);

module.exports = router;
