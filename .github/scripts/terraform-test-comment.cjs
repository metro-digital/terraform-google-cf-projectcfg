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
const path = require('node:path');

const MARKER = '<!-- terraform-test-results -->';
const { OUTCOMES, MOCK_NOTE, renderResults } = require('./terraform-test-results.cjs');

function readResults(directory) {
  if (!fs.existsSync(directory)) return [];
  return fs.readdirSync(directory, { withFileTypes: true })
    .filter(entry => entry.isDirectory() && entry.name.startsWith('terraform-test-result-'))
    .map(entry => JSON.parse(fs.readFileSync(path.join(directory, entry.name, 'result.json'), 'utf8')));
}

module.exports = async function publish({ github, context, core }) {
  const run = context.payload.workflow_run;
  const repo = context.repo;
  const directory = process.env.TEST_RESULTS_DIR;
  const metadataFile = path.join(directory, 'terraform-test-pr', 'pr.json');
  if (!fs.existsSync(metadataFile)) {
    core.info('No PR metadata was uploaded; nothing to comment on.');
    return;
  }
  const metadata = JSON.parse(fs.readFileSync(metadataFile, 'utf8'));
  if (!Number.isSafeInteger(metadata.number) || metadata.number <= 0 || !/^[a-f0-9]{40}$/.test(metadata.head_sha)) {
    throw new Error('Invalid PR metadata');
  }

  const { data: currentRun } = await github.rest.actions.getWorkflowRun({ ...repo, run_id: run.id });
  if (currentRun.status !== 'completed' || currentRun.run_attempt !== run.run_attempt) {
    core.info('A newer run attempt is underway; skip this stale completion.');
    return;
  }
  const { data: pr } = await github.rest.pulls.get({ ...repo, pull_number: metadata.number });
  const associated = run.pull_requests || [];
  const association = associated.find(item => item.number === pr.number);
  const headRepoId = association?.head?.repo?.id || run.head_repository?.id;
  if (pr.state !== 'open' || pr.head.sha !== metadata.head_sha
      || pr.head.repo?.id !== headRepoId
      || (associated.length > 0 && !associated.some(item => item.number === pr.number))
      || (associated.length === 0 && run.head_sha !== pr.head.sha && run.head_sha !== pr.merge_commit_sha)) {
    core.info('The PR no longer matches this test run; skip the comment.');
    return;
  }

  const results = readResults(directory);
  const runUrl = `${process.env.GITHUB_SERVER_URL || 'https://github.com'}/${repo.owner}/${repo.repo}/actions/runs/${run.id}/attempts/${run.run_attempt}`;
  const lines = [
    MARKER,
    `<!-- terraform-test-run:${run.id}:${run.run_attempt} -->`,
    '## Terraform unit tests',
    '',
    `**Workflow: ${OUTCOMES[run.conclusion] || 'Incomplete'}** · [Run ${run.run_number}, attempt ${run.run_attempt}](${runUrl})`,
    '',
  ];
  lines.push(renderResults(results), '', MOCK_NOTE);
  const body = lines.join('\n');

  const comments = await github.paginate(github.rest.issues.listComments, {
    ...repo, issue_number: pr.number, per_page: 100,
  });
  const comment = comments.find(item => item.user.login === 'github-actions[bot]' && item.body?.includes(MARKER));
  const previous = comment?.body?.match(/<!-- terraform-test-run:(\d+):(\d+) -->/);
  if (previous && (BigInt(previous[1]) > BigInt(run.id)
      || (BigInt(previous[1]) === BigInt(run.id) && Number(previous[2]) > run.run_attempt))) {
    core.info('The comment already describes a newer run; leave it unchanged.');
    return;
  }
  if (comment) {
    await github.rest.issues.updateComment({ ...repo, comment_id: comment.id, body });
  } else {
    await github.rest.issues.createComment({ ...repo, issue_number: pr.number, body });
  }
  await core.summary.addRaw(body).write();
};
