/**
 * Convenience launcher for 50-user load/isolation validation.
 * Usage: node tests/run-50-user-test.js
 */

const { spawn } = require("child_process");

const env = {
  ...process.env,
  TEST_USER_COUNT: process.env.TEST_USER_COUNT || "50",
  TEST_CONCURRENCY: process.env.TEST_CONCURRENCY || "10",
};

const child = spawn(process.execPath, ["tests/user-isolation-load-test.js"], {
  env,
  stdio: "inherit",
});

child.on("exit", (code) => process.exit(code || 0));
child.on("error", (error) => {
  console.error("[TEST] Failed to start 50-user test:", error.message);
  process.exit(1);
});
