module.exports = {
    extends: ['@commitlint/config-conventional'],
    ignores: [
        (message) => /^Bumps \[.+]\(.+\) from .+ to .+\.$/m.test(message),
        (message) => message.includes('Signed-off-by: dependabot[bot]'),
    ],
};
