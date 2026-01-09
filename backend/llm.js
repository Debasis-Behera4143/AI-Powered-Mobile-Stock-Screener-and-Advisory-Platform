function parseQueryToDSL(query) {
  if (query.includes("<")) {
    const value = Number(query.match(/\d+/)[0]);
    return {
      filters: [{ field: "pe_ratio", operator: "<", value }],
    };
  }
  return { filters: [] };
}

module.exports = { parseQueryToDSL };
