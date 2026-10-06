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

// Shared artifact validation and Markdown rendering for both reporting workflows.
const VERSION = /^\d+\.\d+\.\d+$/;
const MAJOR = /^(0|[1-9]\d*)$/;
const OUTCOMES = {
  success: '✅ Passed',
  failure: '❌ Failed',
  cancelled: '⏹️ Cancelled',
  skipped: '⏭️ Skipped',
};
const CHECKS = ['format', 'init', 'validate', 'tests'];
const MOCK_NOTE = 'Both Google providers are mocked; tests create no cloud resources.';

// Artifacts are untrusted PR data. Accept only versions and fixed outcomes;
// generate all Markdown here instead of copying artifact text into the comment.
function validateResult(result) {
  // Validate artifact formats independently of the PR's test matrix. The trusted
  // publisher on the default branch must also accept newly tested provider majors.
  if (typeof result.requested_terraform !== 'string' || !VERSION.test(result.requested_terraform)
      || typeof result.provider_major !== 'string' || !MAJOR.test(result.provider_major)
      || !Number.isSafeInteger(Number(result.provider_major))) {
    throw new Error('Invalid test matrix identifiers');
  }
  for (const key of ['terraform', 'google', 'google_beta']) {
    if (result[key] !== null && (typeof result[key] !== 'string' || !VERSION.test(result[key]))) {
      throw new Error(`Invalid installed version: ${key}`);
    }
  }
  if (CHECKS.some(key => !Object.hasOwn(OUTCOMES, result[key]))) {
    throw new Error('Invalid check outcome');
  }
  return result;
}

function renderResults(results) {
  if (!results.length) {
    return 'No matrix results were produced. See the workflow run for the failure details.';
  }
  const lines = [
    '| Terraform | google | google-beta | Formatting | Initialization | Validation | Unit tests |',
    '| --- | --- | --- | --- | --- | --- | --- |',
  ];
  const sorted = results.map(validateResult).sort((a, b) =>
    a.requested_terraform.localeCompare(b.requested_terraform, undefined, { numeric: true })
      || Number(a.provider_major) - Number(b.provider_major));
  for (const result of sorted) {
    const versions = [result.terraform, result.google, result.google_beta]
      .map(version => version || 'Unavailable');
    lines.push(`| ${[...versions, ...CHECKS.map(key => OUTCOMES[result[key]])].join(' | ')} |`);
  }
  return lines.join('\n');
}

module.exports = { OUTCOMES, CHECKS, MOCK_NOTE, renderResults };
