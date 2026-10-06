// Copyright 2026 METRO Digital GmbH
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

const fs = require('node:fs');
const { execFileSync } = require('node:child_process');
const { CHECKS, MOCK_NOTE, renderResults } = require('./terraform-test-results.cjs');

function main() {
  let installed = {};
  try {
    installed = JSON.parse(execFileSync('terraform', ['version', '-json'], {
      encoding: 'utf8', timeout: 10000, stdio: ['ignore', 'pipe', 'pipe'],
    }));
  } catch {
    // Still report failed/skipped checks if setup did not install Terraform.
  }
  const env = process.env;
  const providers = env.INIT_OUTCOME === 'success' ? installed.provider_selections || {} : {};
  const result = {
    terraform: installed.terraform_version || null,
    google: providers['registry.terraform.io/hashicorp/google'] || null,
    google_beta: providers['registry.terraform.io/hashicorp/google-beta'] || null,
    requested_terraform: env.TERRAFORM_VERSION,
    provider_major: env.GOOGLE_PROVIDER_MAJOR,
  };
  for (const check of CHECKS) {
    const variable = check === 'tests' ? 'TEST_OUTCOME' : `${check.toUpperCase()}_OUTCOME`;
    result[check] = env[variable] || 'skipped';
  }
  const summary = [
    `## Terraform ${result.requested_terraform} · Google providers ${result.provider_major}.x`,
    '', renderResults([result]), '', MOCK_NOTE, '',
  ].join('\n');
  if (env.TEST_RESULT_FILE) fs.writeFileSync(env.TEST_RESULT_FILE, JSON.stringify(result));
  fs.appendFileSync(env.GITHUB_STEP_SUMMARY, summary);
}

if (require.main === module) main();
module.exports = main;
