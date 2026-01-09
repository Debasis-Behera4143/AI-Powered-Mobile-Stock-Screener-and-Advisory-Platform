/**
 * SETUP VERIFICATION SCRIPT
 * 
 * Run this BEFORE starting the server to check if everything is configured
 * 
 * Usage: node verify-setup.js
 */

const fs = require('fs');
const { execSync } = require('child_process');

const colors = {
  reset: '\x1b[0m',
  green: '\x1b[32m',
  red: '\x1b[31m',
  yellow: '\x1b[33m',
  blue: '\x1b[34m',
  cyan: '\x1b[36m'
};

console.log('\n' + '='.repeat(70));
console.log(`${colors.cyan}🔍 AI STOCK SCREENER - SETUP VERIFICATION${colors.reset}`);
console.log('='.repeat(70) + '\n');

const checks = {
  passed: 0,
  failed: 0,
  warnings: 0
};

/**
 * CHECK 1: Node.js Version
 */
console.log('1️⃣  Checking Node.js version...');
try {
  const nodeVersion = process.version;
  const majorVersion = parseInt(nodeVersion.split('.')[0].substring(1));
  
  if (majorVersion >= 16) {
    console.log(`   ${colors.green}✓${colors.reset} Node.js ${nodeVersion} (Required: ≥16.0.0)`);
    checks.passed++;
  } else {
    console.log(`   ${colors.red}✗${colors.reset} Node.js ${nodeVersion} is too old`);
    console.log(`   ${colors.yellow}→ Please install Node.js 16 or higher${colors.reset}`);
    checks.failed++;
  }
} catch (error) {
  console.log(`   ${colors.red}✗${colors.reset} Could not check Node.js version`);
  checks.failed++;
}

/**
 * CHECK 2: npm Packages
 */
console.log('\n2️⃣  Checking npm packages...');
try {
  const packageJson = JSON.parse(fs.readFileSync('./package.json', 'utf8'));
  const nodeModulesExists = fs.existsSync('./node_modules');
  
  if (nodeModulesExists) {
    console.log(`   ${colors.green}✓${colors.reset} node_modules folder exists`);
    
    // Check if critical packages exist
    const criticalPackages = ['express', 'pg', 'axios', 'dotenv'];
    let allInstalled = true;
    
    for (const pkg of criticalPackages) {
      if (!fs.existsSync(`./node_modules/${pkg}`)) {
        console.log(`   ${colors.red}✗${colors.reset} Package missing: ${pkg}`);
        allInstalled = false;
      }
    }
    
    if (allInstalled) {
      console.log(`   ${colors.green}✓${colors.reset} All critical packages installed`);
      checks.passed++;
    } else {
      console.log(`   ${colors.yellow}→ Run: npm install${colors.reset}`);
      checks.failed++;
    }
  } else {
    console.log(`   ${colors.red}✗${colors.reset} node_modules not found`);
    console.log(`   ${colors.yellow}→ Run: npm install${colors.reset}`);
    checks.failed++;
  }
} catch (error) {
  console.log(`   ${colors.red}✗${colors.reset} Could not verify packages: ${error.message}`);
  checks.failed++;
}

/**
 * CHECK 3: .env File
 */
console.log('\n3️⃣  Checking environment configuration...');
try {
  if (fs.existsSync('./.env')) {
    console.log(`   ${colors.green}✓${colors.reset} .env file exists`);
    
    const envContent = fs.readFileSync('./.env', 'utf8');
    
    // Check required variables
    const requiredVars = ['DB_PASSWORD', 'DB_NAME', 'DB_USER'];
    let allConfigured = true;
    
    for (const varName of requiredVars) {
      if (!envContent.includes(`${varName}=`) || envContent.includes(`${varName}=your_`)) {
        console.log(`   ${colors.yellow}⚠${colors.reset} ${varName} not configured in .env`);
        allConfigured = false;
        checks.warnings++;
      }
    }
    
    if (allConfigured) {
      console.log(`   ${colors.green}✓${colors.reset} Required variables configured`);
      checks.passed++;
    } else {
      console.log(`   ${colors.yellow}→ Edit .env and set actual values${colors.reset}`);
    }
    
    // Check optional API keys
    if (!envContent.includes('ALPHA_VANTAGE_API_KEY=') || 
        envContent.includes('ALPHA_VANTAGE_API_KEY=your_') ||
        envContent.includes('ALPHA_VANTAGE_API_KEY=demo')) {
      console.log(`   ${colors.blue}ℹ${colors.reset} Alpha Vantage API key not set (will use mock data)`);
    }
    
    if (!envContent.includes('OPENAI_API_KEY=') || 
        envContent.includes('OPENAI_API_KEY=your_')) {
      console.log(`   ${colors.blue}ℹ${colors.reset} OpenAI API key not set (will use mock LLM parser)`);
    }
    
  } else {
    console.log(`   ${colors.red}✗${colors.reset} .env file not found`);
    console.log(`   ${colors.yellow}→ Copy .env.example to .env${colors.reset}`);
    checks.failed++;
  }
} catch (error) {
  console.log(`   ${colors.red}✗${colors.reset} Could not verify .env: ${error.message}`);
  checks.failed++;
}

/**
 * CHECK 4: PostgreSQL
 */
console.log('\n4️⃣  Checking PostgreSQL...');
try {
  const psqlVersion = execSync('psql --version', { encoding: 'utf8' });
  console.log(`   ${colors.green}✓${colors.reset} PostgreSQL installed: ${psqlVersion.trim()}`);
  checks.passed++;
} catch (error) {
  console.log(`   ${colors.red}✗${colors.reset} PostgreSQL not found or not in PATH`);
  console.log(`   ${colors.yellow}→ Install PostgreSQL from: https://www.postgresql.org/download/${colors.reset}`);
  checks.failed++;
}

/**
 * CHECK 5: Project Files
 */
console.log('\n5️⃣  Checking project files...');
const requiredFiles = [
  'server.js',
  'app.js',
  'database.js',
  'llm.js',
  'routes/stocks.routes.js',
  'controllers/stocks.controller.js',
  'services/marketData.service.js'
];

let allFilesPresent = true;
for (const file of requiredFiles) {
  if (!fs.existsSync(file)) {
    console.log(`   ${colors.red}✗${colors.reset} Missing: ${file}`);
    allFilesPresent = false;
  }
}

if (allFilesPresent) {
  console.log(`   ${colors.green}✓${colors.reset} All core files present (${requiredFiles.length} files)`);
  checks.passed++;
} else {
  console.log(`   ${colors.red}✗${colors.reset} Some core files are missing`);
  checks.failed++;
}

/**
 * SUMMARY
 */
console.log('\n' + '='.repeat(70));
console.log('📊 VERIFICATION SUMMARY');
console.log('='.repeat(70));
console.log(`${colors.green}Passed:   ${checks.passed}${colors.reset}`);
console.log(`${colors.red}Failed:   ${checks.failed}${colors.reset}`);
console.log(`${colors.yellow}Warnings: ${checks.warnings}${colors.reset}`);
console.log('='.repeat(70) + '\n');

if (checks.failed === 0) {
  console.log(`${colors.green}🎉 SETUP COMPLETE! You're ready to run the server!${colors.reset}\n`);
  console.log('Next steps:');
  console.log(`  1. ${colors.cyan}npm start${colors.reset}                # Start the server`);
  console.log(`  2. ${colors.cyan}node test-api.js${colors.reset}         # Test all endpoints`);
  console.log(`  3. Open ${colors.cyan}http://localhost:3000${colors.reset}\n`);
} else {
  console.log(`${colors.yellow}⚠️  SETUP INCOMPLETE${colors.reset}`);
  console.log(`\nPlease fix the issues above before starting the server.\n`);
  console.log('Common fixes:');
  console.log(`  • ${colors.cyan}npm install${colors.reset}               # Install dependencies`);
  console.log(`  • ${colors.cyan}cp .env.example .env${colors.reset}      # Create .env file`);
  console.log(`  • Edit .env with your actual values\n`);
  process.exit(1);
}
